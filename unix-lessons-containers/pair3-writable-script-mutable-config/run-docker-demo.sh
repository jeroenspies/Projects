#!/usr/bin/env bash
set -euo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "${DIR}/.." && pwd)
# shellcheck source=SCRIPTDIR/../scripts/lib.sh
source "${ROOT}/scripts/lib.sh"

IMAGE="unix-lessons-pair3:local"
log=$(mktemp)
cmd=""

summary_open pair3-writable-script
transcript "## Pair 3: writable script"
transcript_blank

export DOCKER_BUILDKIT=1
docker build --pull -t "${IMAGE}" "${DIR}" || fail "docker build failed for ${IMAGE}"

cmd=$(format_cmd docker run --rm "${IMAGE}" /usr/local/bin/run-inside.sh)
set +e
docker run --rm "${IMAGE}" /usr/local/bin/run-inside.sh 2>&1 | tee "${log}" >/dev/null
rc=${PIPESTATUS[0]}
set -e
transcript_cmd_result "writable script" "${cmd}" "${log}" "${rc}"
summary_file "${log}"
summary_blank
if [[ "$rc" -ne 0 ]]; then
  fail "pair 3 container demo exited ${rc}"
fi
