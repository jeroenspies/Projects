#!/usr/bin/env bash
# Print the runner's docker socket metadata and user id. Do not mount or use the socket.
set -euo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "${DIR}/.." && pwd)
# shellcheck source=SCRIPTDIR/../scripts/lib.sh
source "${ROOT}/scripts/lib.sh"

summary_open pair4-socket-metadata
transcript "## Pair 4: docker group and socket metadata"
transcript_blank

summary "## Pair 4: docker group and socket metadata"
summary_blank

sock=/var/run/docker.sock
if [[ ! -S "$sock" ]]; then
  fail "${sock} is not a socket on this runner"
fi

ls_file=$(mktemp)
stat_file=$(mktemp)
id_file=$(mktemp)
groups_file=$(mktemp)
ls_rc=0
stat_rc=0
id_rc=0
groups_rc=0

set +e
# ls -l is the socket metadata this demo records, not a filename iterator.
# shellcheck disable=SC2012
ls -l "$sock" 2>&1 | tee "${ls_file}" >/dev/null
ls_rc=${PIPESTATUS[0]}
set -e
transcript_cmd_result "ls" "$(format_cmd ls -l "$sock")" "${ls_file}" "${ls_rc}"
[[ "${ls_rc}" -eq 0 ]] || fail "ls ${sock} exited ${ls_rc}"

set +e
stat -c '%A %a %U %G %F' "$sock" 2>&1 | tee "${stat_file}" >/dev/null
stat_rc=${PIPESTATUS[0]}
set -e
transcript_cmd_result "stat" "$(format_cmd stat -c '%A %a %U %G %F' "$sock")" "${stat_file}" "${stat_rc}"
[[ "${stat_rc}" -eq 0 ]] || fail "stat ${sock} exited ${stat_rc}"

set +e
id 2>&1 | tee "${id_file}" >/dev/null
id_rc=${PIPESTATUS[0]}
set -e
transcript_cmd_result "id" "$(format_cmd id)" "${id_file}" "${id_rc}"
[[ "${id_rc}" -eq 0 ]] || fail "id exited ${id_rc}"

set +e
id -nG 2>&1 | tee "${groups_file}" >/dev/null
groups_rc=${PIPESTATUS[0]}
set -e
transcript_cmd_result "groups" "$(format_cmd id -nG)" "${groups_file}" "${groups_rc}"
[[ "${groups_rc}" -eq 0 ]] || fail "id -nG exited ${groups_rc}"

ls_out=$(cat "${ls_file}")
stat_out=$(cat "${stat_file}")
id_out=$(cat "${id_file}")
id_name=$(id -un)
groups_out=$(cat "${groups_file}")
in_docker=no
if printf '%s\n' "$groups_out" | tr ' ' '\n' | grep -qx 'docker'; then
  in_docker=yes
fi

summary "\`ls -l ${sock}\`:"
summary '```'
summary "${ls_out}"
summary '```'
summary_blank
summary "\`stat\`: \`${stat_out}\`"
summary_blank
summary "Runner user: \`${id_name}\`"
summary_blank
summary "\`id\`:"
summary '```'
summary "${id_out}"
summary '```'
summary_blank
summary "In group \`docker\`: ${in_docker}"
summary_blank
sudo_out=$(mktemp)
set +e
# The redirect belongs to this shell. sudo only runs `true`.
# shellcheck disable=SC2024
sudo -n true >"${sudo_out}" 2>&1
sudo_rc=$?
set -e
transcript_cmd_result "sudo -n true" "$(format_cmd sudo -n true)" "${sudo_out}" "${sudo_rc}"
summary "\`sudo -n true\` exit ${sudo_rc}."
if [[ "${sudo_rc}" -eq 0 ]]; then
  summary "The runner user can already become root via passwordless sudo. A container breakout on this VM would not show a new privilege."
else
  summary "\`sudo -n true\` did not succeed on this machine. Output:"
  summary '```'
  sed -n '1,10p' "${sudo_out}" | while IFS= read -r line; do
    summary "$line"
  done
  summary '```'
fi
summary_blank
summary "The socket is not mounted into a container and no client talks to it. sudo is not used for anything except \`true\`."
summary_blank
summary "Pair 4 host observations recorded."
summary_blank
