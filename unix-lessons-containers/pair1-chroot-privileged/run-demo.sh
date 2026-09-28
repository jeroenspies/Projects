#!/usr/bin/env bash
# Pair 1: compare capability sets, device and mount counts, port 80 bind, and chroot().
# The privileged container only runs observe.sh. Nothing mounts the host or escapes.
set -euo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "${DIR}/.." && pwd)
# shellcheck source=SCRIPTDIR/../scripts/lib.sh
source "${ROOT}/scripts/lib.sh"

IMAGE="unix-lessons-pair1:local"

summary_open pair1-chroot-privileged
transcript "## Pair 1: chroot and capabilities"
transcript_blank

summary "## Pair 1: chroot and capabilities"
summary_blank

export DOCKER_BUILDKIT=1
docker build --pull -t "${IMAGE}" "${DIR}" || fail "docker build failed for ${IMAGE}"

obs_get() {
  local file="$1"
  local key="$2"
  local value
  value=$(sed -n "s/^OBS ${key}=//p" "$file" | head -n 1)
  if [[ -z "$value" ]]; then
    fail "missing OBS ${key} in ${file}"
  fi
  printf '%s' "$value"
}

obs_opt() {
  local file="$1"
  local key="$2"
  local value
  value=$(sed -n "s/^OBS ${key}=//p" "$file" | head -n 1)
  printf '%s' "${value:-n/a}"
}

# run_cmd EXPECT OUTFILE [docker args...] -- COMMAND...
run_cmd() {
  local expect="$1"
  local outfile="$2"
  shift 2
  local -a docker_args=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    docker_args+=("$1")
    shift
  done
  [[ "${1:-}" == "--" ]] || fail "run_cmd missing -- separator"
  shift
  local rc
  LAST_CMD=$(format_cmd docker run --rm "${docker_args[@]}" "${IMAGE}" "$@")
  set +e
  docker run --rm "${docker_args[@]}" "${IMAGE}" "$@" 2>&1 | tee "${outfile}" >/dev/null
  rc=${PIPESTATUS[0]}
  set -e
  printf 'exit=%s expected=%s cmd=%s\n' "$rc" "$expect" "$*"
  cat "${outfile}"
  if [[ "$rc" -ne "$expect" ]]; then
    transcript_block "failed command" "${LAST_CMD}" "${outfile}"
    fail "exit ${rc} != ${expect} for $*"
  fi
}

drop_out=$(mktemp)
net_out=$(mktemp)
priv_out=$(mktemp)
nnp_out=$(mktemp)

run_cmd 0 "${drop_out}" --cap-drop ALL -- \
  /usr/local/bin/observe.sh
transcript_block "--cap-drop ALL" "${LAST_CMD}" "${drop_out}"
transcript "Exit 0."
transcript_blank
run_cmd 0 "${net_out}" --cap-drop ALL --cap-add NET_BIND_SERVICE -- \
  /usr/local/bin/observe.sh
transcript_block "--cap-drop ALL --cap-add NET_BIND_SERVICE" "${LAST_CMD}" "${net_out}"
run_cmd 0 "${priv_out}" --privileged -- \
  /usr/local/bin/observe.sh
transcript_block "--privileged" "${LAST_CMD}" "${priv_out}"
run_cmd 0 "${nnp_out}" --cap-drop ALL --security-opt no-new-privileges -- \
  /usr/local/bin/observe.sh
transcript_cmd_result "--cap-drop ALL --security-opt no-new-privileges" "${LAST_CMD}" "${nnp_out}" "0"

drop_dec=$(obs_get "${drop_out}" CAPEFF_DECODED)
net_dec=$(obs_get "${net_out}" CAPEFF_DECODED)
priv_dec=$(obs_get "${priv_out}" CAPEFF_DECODED)
drop_nnp=$(obs_get "${drop_out}" NONEWPRIVS)
nnp=$(obs_get "${nnp_out}" NONEWPRIVS)
drop_dev=$(obs_get "${drop_out}" DEV_COUNT)
net_dev=$(obs_get "${net_out}" DEV_COUNT)
priv_dev=$(obs_get "${priv_out}" DEV_COUNT)
drop_mnt=$(obs_get "${drop_out}" MOUNT_COUNT)
net_mnt=$(obs_get "${net_out}" MOUNT_COUNT)
priv_mnt=$(obs_get "${priv_out}" MOUNT_COUNT)

case "${drop_dec}" in
  *cap_*) fail "cap-drop ALL still decoded a capability: ${drop_dec}" ;;
esac
case "${net_dec}" in
  *cap_net_bind_service*) ;;
  *) fail "expected cap_net_bind_service, got: ${net_dec}" ;;
esac
case "${net_dec}" in
  *cap_sys_admin*) fail "NET_BIND_SERVICE scenario included cap_sys_admin: ${net_dec}" ;;
esac
case "${priv_dec}" in
  *cap_sys_admin*) ;;
  *) fail "privileged CapEff did not include cap_sys_admin: ${priv_dec}" ;;
esac
[[ "${drop_nnp}" == "0" ]] || fail "default NoNewPrivs was ${drop_nnp}, expected 0"
[[ "${nnp}" == "1" ]] || fail "no-new-privileges NoNewPrivs was ${nnp}, expected 1"
[[ "${priv_dev}" -gt "${drop_dev}" ]] || fail "privileged /dev count ${priv_dev} was not greater than ${drop_dev}"
# --privileged skips the masked /proc and /sys mounts the default runtime adds,
# so the mount count goes down while /dev grows. Either direction is a real change.
[[ "${priv_mnt}" -ne "${drop_mnt}" ]] || fail "privileged mount count matched the dropped container (${priv_mnt})"
[[ "${net_dev}" -eq "${drop_dev}" ]] || fail "NET_BIND_SERVICE changed /dev count (${net_dev} vs ${drop_dev})"
[[ "${net_mnt}" -eq "${drop_mnt}" ]] || fail "NET_BIND_SERVICE changed mount count (${net_mnt} vs ${drop_mnt})"

summary "### Capability, device, and mount counts"
summary_blank
summary "| Scenario | CapEff | NoNewPrivs | /dev entries | mounts | AppArmor |"
summary "| --- | --- | --- | --- | --- | --- |"
summary "| \`--cap-drop ALL\` | \`${drop_dec}\` | ${drop_nnp} | ${drop_dev} | ${drop_mnt} | \`$(obs_opt "${drop_out}" APPARMOR)\` |"
summary "| \`--cap-drop ALL --cap-add NET_BIND_SERVICE\` | \`${net_dec}\` | $(obs_get "${net_out}" NONEWPRIVS) | ${net_dev} | ${net_mnt} | \`$(obs_opt "${net_out}" APPARMOR)\` |"
summary "| \`--privileged\` | includes \`cap_sys_admin\` | $(obs_get "${priv_out}" NONEWPRIVS) | ${priv_dev} | ${priv_mnt} | \`$(obs_opt "${priv_out}" APPARMOR)\` |"
summary "| \`--cap-drop ALL --security-opt no-new-privileges\` | $(obs_get "${nnp_out}" CAPEFF_DECODED) | ${nnp} | $(obs_get "${nnp_out}" DEV_COUNT) | $(obs_get "${nnp_out}" MOUNT_COUNT) | \`$(obs_opt "${nnp_out}" APPARMOR)\` |"
summary_blank
summary "\`--privileged\` changed the mount count from ${drop_mnt} to ${priv_mnt}. The default runtime adds masked \`/proc\` and \`/sys\` mounts that \`--privileged\` does not, so that count is often smaller while \`/dev\` is larger (${drop_dev} -> ${priv_dev})."
summary_blank
summary "Privileged CapEff hex: \`$(obs_get "${priv_out}" CAPEFF_HEX)\`"
summary_blank
summary "Privileged CapEff decoded:"
summary_blank
summary '```'
summary "${priv_dec}"
summary '```'
summary_blank
drop_hex=$(obs_get "${drop_out}" CAPEFF_HEX)
net_hex=$(obs_get "${net_out}" CAPEFF_HEX)
priv_hex=$(obs_get "${priv_out}" CAPEFF_HEX)
[[ "${drop_hex}" != "${net_hex}" && "${net_hex}" != "${priv_hex}" && "${drop_hex}" != "${priv_hex}" ]] \
  || fail "the three CapEff masks were not all different (${drop_hex} / ${net_hex} / ${priv_hex})"

summary "Ambient capability hex (drop-all / net-bind / privileged): \`$(obs_get "${drop_out}" CAPAMB_HEX)\` / \`$(obs_get "${net_out}" CAPAMB_HEX)\` / \`$(obs_get "${priv_out}" CAPAMB_HEX)\`"
summary_blank
summary "\`grep ^Cap /proc/self/status\` for the three masks:"
summary_blank
summary '```'
{
  echo "--cap-drop ALL"
  sed -n 's/^OBS CAPLINE //p' "${drop_out}"
  echo "--cap-drop ALL --cap-add NET_BIND_SERVICE"
  sed -n 's/^OBS CAPLINE //p' "${net_out}"
  echo "--privileged"
  sed -n 's/^OBS CAPLINE //p' "${priv_out}"
} | while IFS= read -r line; do
  summary "$line"
done
summary '```'
summary_blank
summary "\`id\` was written to \`/tmp/id-proof\` inside each container. Drop-all id: \`$(obs_get "${drop_out}" ID)\`"
summary_blank

# Default network namespace: Docker has set ip_unprivileged_port_start=0 since 20.10
# (moby PR 41030). A non-root bind of port 80 then succeeds with no capability.
default_out=$(mktemp)
nonroot_bind=$(mktemp)
nonroot_caps=$(mktemp)
run_cmd 0 "${default_out}" -- /usr/local/bin/observe.sh
transcript_block "default capability set" "${LAST_CMD}" "${default_out}"
default_sysctl=$(obs_get "${default_out}" UNPRIV_PORT_START)
[[ "${default_sysctl}" == "0" ]] || fail "default ip_unprivileged_port_start was ${default_sysctl}, expected 0"
run_cmd 0 "${nonroot_bind}" --user 1000:1000 -- /usr/local/bin/bind80
transcript_cmd_result "non-root bind80" "${LAST_CMD}" "${nonroot_bind}" "0"
run_cmd 0 "${nonroot_caps}" --user 1000:1000 --cap-add NET_BIND_SERVICE -- /usr/local/bin/observe.sh
nonroot_eff=$(obs_get "${nonroot_caps}" CAPEFF_HEX)
nonroot_amb=$(obs_get "${nonroot_caps}" CAPAMB_HEX)
[[ "${nonroot_eff}" == "0000000000000000" ]] || fail "non-root CapEff after --cap-add NET_BIND_SERVICE was ${nonroot_eff}, expected 0"
[[ "${nonroot_amb}" == "0000000000000000" ]] || fail "non-root CapAmb after --cap-add NET_BIND_SERVICE was ${nonroot_amb}, expected 0"

# Root, with the privileged-port floor restored, is the case that still needs the capability.
# bind80 returns 10 for EACCES or EPERM. This kernel returns EACCES (errno 13), not EPERM.
root_deny=$(mktemp)
root_allow=$(mktemp)
sysctl_args=(--sysctl net.ipv4.ip_unprivileged_port_start=1024)
run_cmd 10 "${root_deny}" --cap-drop NET_BIND_SERVICE "${sysctl_args[@]}" -- /usr/local/bin/bind80
transcript_cmd_result "root bind80 --cap-drop NET_BIND_SERVICE" "${LAST_CMD}" "${root_deny}" "10"
if ! grep -q 'errno=13' "${root_deny}"; then
  cat "${root_deny}" >&2
  fail "root bind without NET_BIND_SERVICE was denied, but not with errno 13 (EACCES)"
fi
run_cmd 0 "${root_allow}" "${sysctl_args[@]}" -- /usr/local/bin/bind80
transcript_cmd_result "root bind80 default capabilities" "${LAST_CMD}" "${root_allow}" "0"
root_deny_line=$(grep 'bind:' "${root_deny}" | head -n 1)

summary "### Port 80"
summary_blank
summary "A default container (its own network namespace, no \`--sysctl\`) has \`net.ipv4.ip_unprivileged_port_start=${default_sysctl}\`. That default lets a non-root process bind \`127.0.0.1:80\` with no capability. The helper binds loopback and closes the socket."
summary_blank
summary "| Process | Flags | \`ip_unprivileged_port_start\` | Result |"
summary "| --- | --- | --- | --- |"
summary "| uid 1000, \`bind80\` | default | ${default_sysctl} | allowed |"
summary "| uid 1000, \`observe.sh\` | \`--cap-add NET_BIND_SERVICE\` | $(obs_get "${nonroot_caps}" UNPRIV_PORT_START) | CapEff \`${nonroot_eff}\`, CapAmb \`${nonroot_amb}\` |"
summary "| root, \`bind80\` | \`--cap-drop NET_BIND_SERVICE\` | 1024 | denied: ${root_deny_line} |"
summary "| root, \`bind80\` | default capability set | 1024 | allowed |"
summary_blank
summary "The denial is EACCES (errno 13, \`Permission denied\`), not EPERM. \`--cap-add\` did not put \`NET_BIND_SERVICE\` into the non-root effective or ambient set."
summary_blank

chroot_deny=$(mktemp)
chroot_allow=$(mktemp)
run_cmd 10 "${chroot_deny}" --cap-drop ALL -- /usr/local/bin/try-chroot
transcript_cmd_result "chroot --cap-drop ALL" "${LAST_CMD}" "${chroot_deny}" "10"

chroot_positive="syscall returned success under the default Docker profile, then the process exited"
set +e
docker run --rm --cap-drop ALL --cap-add SYS_CHROOT "${IMAGE}" /usr/local/bin/try-chroot >"${chroot_allow}" 2>&1
chroot_rc=$?
set -e
cat "${chroot_allow}"
if [[ "${chroot_rc}" -ne 0 ]]; then
  chroot_unconfined=$(mktemp)
  set +e
  docker run --rm --cap-drop ALL --cap-add SYS_CHROOT \
    --security-opt apparmor=unconfined \
    "${IMAGE}" /usr/local/bin/try-chroot >"${chroot_unconfined}" 2>&1
  chroot_unconfined_rc=$?
  set -e
  cat "${chroot_unconfined}"
  if [[ "${chroot_unconfined_rc}" -ne 0 ]]; then
    fail "chroot with CAP_SYS_CHROOT failed under the default profile (exit ${chroot_rc}) and with apparmor=unconfined (exit ${chroot_unconfined_rc})"
  fi
  chroot_positive="default Docker profile denied the syscall (exit ${chroot_rc}); it succeeded only with apparmor=unconfined. The call is still chroot(\"/tmp\") followed by exit."
fi

summary "### chroot()"
summary_blank
summary "| Flags | Result |"
summary "| --- | --- |"
summary "| \`--cap-drop ALL\` | EPERM (exit 10) |"
summary "| \`--cap-drop ALL --cap-add SYS_CHROOT\` | ${chroot_positive} |"
summary_blank
summary "A successful call is \`chroot(\"/tmp\")\` followed by exit. It does not construct a jail escape."
summary_blank
summary "Pair 1 assertions passed."
summary_blank
