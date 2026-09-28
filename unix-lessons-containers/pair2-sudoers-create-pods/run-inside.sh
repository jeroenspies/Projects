#!/bin/sh
# Show sudo -l, a NOEXEC exec test, and sudoedit. Does not run less.
set -eu

echo "127.0.0.1 $(hostname) localhost" >> /etc/hosts

echo "## Pair 2: sudoers"
echo
echo "sudo version:"
echo '```'
sudo --version | head -n 3
echo '```'
echo

echo "### sudo -l"
echo
echo '```'
su -s /bin/sh testuser -c 'sudo -n -l'
echo '```'
echo

listing=$(su -s /bin/sh testuser -c 'sudo -n -l')
echo "$listing" | grep -q '/usr/bin/less' || {
  echo "FAIL: sudo -l did not list /usr/bin/less"
  exit 1
}
echo "$listing" | grep -q 'NOEXEC:.*try-exec-noexec' || {
  echo "FAIL: sudo -l did not list the NOEXEC rule"
  exit 1
}
echo "$listing" | grep -q 'sudoedit /etc/hostname' || {
  echo "FAIL: sudo -l did not list sudoedit"
  exit 1
}

echo "less is installed at /usr/bin/less and is not executed."
echo "Shell escapes for that rule are documented at https://gtfobins.github.io/gtfobins/less/ and are not reproduced here."
echo

echo "### exec /bin/true via sudo"
echo
set +e
su -s /bin/sh testuser -c 'sudo -n /usr/local/bin/try-exec' >/tmp/try-exec.out 2>/tmp/try-exec.err
plain_rc=$?
set -e
echo "try-exec without NOEXEC: exit ${plain_rc}"
cat /tmp/try-exec.out /tmp/try-exec.err
if [ "$plain_rc" -ne 0 ]; then
  echo "FAIL: the helper without NOEXEC could not exec /bin/true"
  exit 1
fi

set +e
su -s /bin/sh testuser -c 'sudo -n /usr/local/bin/try-exec-noexec' >/tmp/try-exec-noexec.out 2>/tmp/try-exec-noexec.err
noexec_rc=$?
set -e
echo "try-exec with NOEXEC: exit ${noexec_rc}"
cat /tmp/try-exec-noexec.out /tmp/try-exec-noexec.err

noexec_note=""
if [ "$noexec_rc" -eq 10 ]; then
  noexec_note="blocked execve with EPERM (exit 10)"
elif [ "$noexec_rc" -eq 0 ]; then
  noexec_note="NOEXEC did not block exec of /bin/true (exit 0)"
elif grep -q 'errno=13' /tmp/try-exec-noexec.err; then
  # EACCES is 13. "Permission denied" is not EPERM (1, "Operation not permitted").
  noexec_note="blocked execve with EACCES (errno 13), not EPERM (exit ${noexec_rc})"
elif grep -q 'exec /bin/true failed' /tmp/try-exec-noexec.err; then
  noexec_note="exec failed with a non-EPERM status (exit ${noexec_rc})"
else
  echo "FAIL: NOEXEC helper did not run (exit ${noexec_rc})"
  exit 1
fi
echo "NOEXEC_RESULT=${noexec_note}"
echo

before=$(sha256sum /etc/hostname)
su -s /bin/sh testuser -c 'sudoedit -n /etc/hostname' >/tmp/sudoedit.out 2>/tmp/sudoedit.err || {
  echo "FAIL: sudoedit failed"
  cat /tmp/sudoedit.out /tmp/sudoedit.err
  exit 1
}
after=$(sha256sum /etc/hostname)
if [ "$before" != "$after" ]; then
  echo "FAIL: sudoedit changed /etc/hostname"
  exit 1
fi
if [ ! -f /tmp/sudoedit-id ]; then
  echo "FAIL: editor did not write /tmp/sudoedit-id"
  cat /tmp/sudoedit.out /tmp/sudoedit.err
  exit 1
fi
editor_id=$(cat /tmp/sudoedit-id)
echo "### sudoedit"
echo
echo "Editor id (must be the invoking user, not root):"
echo '```'
echo "$editor_id"
echo '```'
echo
echo "$editor_id" | grep -q 'uid=1000' || {
  echo "FAIL: sudoedit editor was not uid 1000"
  exit 1
}
case "$editor_id" in
  *'uid=0'*)
    echo "FAIL: sudoedit editor ran as root"
    exit 1
    ;;
esac
echo "sudoedit left /etc/hostname unchanged (${after})."
echo
echo "| Check | Result |"
echo "| --- | --- |"
echo "| \`sudo -l\` lists \`NOPASSWD: /usr/bin/less\` | yes |"
echo "| \`sudo -l\` lists \`NOEXEC: /usr/local/bin/try-exec-noexec\` | yes |"
echo "| helper without NOEXEC execs \`/bin/true\` | exit 0 |"
echo "| helper with NOEXEC | ${noexec_note} |"
echo "| sudoedit editor uid | 1000 |"
echo
echo "Pair 2 sudo assertions passed."
