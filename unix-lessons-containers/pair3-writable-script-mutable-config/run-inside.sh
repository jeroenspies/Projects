#!/bin/sh
# A root loop stands in for cron. The proof file stays inside this container.
set -eu

echo "## Pair 3: writable script run by root"
echo

id_user=$(su -s /bin/sh appuser -c 'id')
echo "Non-root user: ${id_user}"
echo "$id_user" | grep -q 'uid=1000' || {
  echo "FAIL: appuser is not uid 1000"
  exit 1
}

mkdir -p /opt
printf '%s\n' '#!/bin/sh' 'echo tick' > /opt/job.sh
chown root:root /opt/job.sh
chmod 0777 /opt/job.sh

(
  while true; do
    /opt/job.sh >> /tmp/cron.log 2>&1 || true
    sleep 1
  done
) &
loop_pid=$!

su -s /bin/sh appuser -c 'printf "\nid > /tmp/proof\n" >> /opt/job.sh'

i=0
while [ "$i" -lt 20 ]; do
  if [ -f /tmp/proof ]; then
    break
  fi
  i=$((i + 1))
  sleep 1
done

kill "$loop_pid" 2>/dev/null || true
wait "$loop_pid" 2>/dev/null || true

if [ ! -f /tmp/proof ]; then
  echo "FAIL: /tmp/proof was not created"
  echo "script after append:"
  cat /opt/job.sh
  echo "cron log:"
  cat /tmp/cron.log 2>/dev/null || true
  exit 1
fi

proof=$(cat /tmp/proof)
echo "### Writable script"
echo
echo "Mode of /opt/job.sh:"
ls -l /opt/job.sh
echo
echo "Script contents after the non-root append:"
echo '```'
cat /opt/job.sh
echo '```'
echo
echo "Contents of /tmp/proof (written by the root loop):"
echo '```'
echo "$proof"
echo '```'
echo
echo "$proof" | grep -q 'uid=0(root)' || {
  echo "FAIL: proof did not show uid=0(root)"
  exit 1
}

mkdir -p /opt/fixed
printf '%s\n' '#!/bin/sh' 'echo fixed-tick' > /opt/fixed/job.sh
chown root:root /opt/fixed /opt/fixed/job.sh
chmod 0755 /opt/fixed /opt/fixed/job.sh

set +e
su -s /bin/sh appuser -c 'printf "\nid > /tmp/should-not\n" >> /opt/fixed/job.sh' >/tmp/fixed.out 2>/tmp/fixed.err
fixed_rc=$?
set -e
if [ "$fixed_rc" -eq 0 ]; then
  echo "FAIL: non-root user appended to the fixed script"
  exit 1
fi
if grep -q 'should-not' /opt/fixed/job.sh; then
  echo "FAIL: fixed script contents changed"
  exit 1
fi
if [ -e /opt/fixed/evil.sh ]; then
  echo "FAIL: leftover file in the fixed directory"
  exit 1
fi
set +e
su -s /bin/sh appuser -c 'touch /opt/fixed/evil.sh' >/tmp/fixed-touch.out 2>/tmp/fixed-touch.err
touch_rc=$?
set -e
if [ "$touch_rc" -eq 0 ]; then
  echo "FAIL: non-root user created a file in /opt/fixed"
  exit 1
fi

echo "### Fixed script"
echo
ls -ld /opt/fixed
ls -l /opt/fixed/job.sh
echo
echo "Append exit ${fixed_rc}:"
cat /tmp/fixed.err /tmp/fixed.out
echo "Create exit ${touch_rc}:"
cat /tmp/fixed-touch.err /tmp/fixed-touch.out
echo
grep -i -q 'permission denied' /tmp/fixed.err || {
  echo "FAIL: expected a permission denial when appending to the fixed script"
  exit 1
}

echo "| Setup | Non-root write | What ran |"
echo "| --- | --- | --- |"
echo "| \`/opt/job.sh\` mode 0777 | append succeeded | root loop wrote \`uid=0(root)\` to \`/tmp/proof\` |"
echo "| \`/opt/fixed/job.sh\` root:root 0755 in a root-only directory | permission denied | file unchanged |"
echo
echo "Pair 3 container assertions passed."
