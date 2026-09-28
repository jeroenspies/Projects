#!/usr/bin/env bash
# Write tool versions into summaries/environment-<job>.md so the artifact
# keeps them after the job log expires.
set -euo pipefail

job="${1:?usage: record-environment.sh docker|kind}"
case "${job}" in
  docker|kind) ;;
  *) printf 'unknown job: %s\n' "${job}" >&2; exit 1 ;;
esac

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/lib.sh
source "${DIR}/lib.sh"

summary_open "environment-${job}"
transcript "## Environment (${job})"
transcript_blank

run_record() {
  local heading="$1"
  shift
  local log rc cmd_s
  log=$(mktemp)
  cmd_s=$(format_cmd "$@")
  set +e
  "$@" >"${log}" 2>&1
  rc=$?
  set -e
  transcript_block "${heading}" "${cmd_s}" "${log}"
  transcript "Exit ${rc}."
  transcript_blank
  [[ "${rc}" -eq 0 ]] || fail "${heading} exited ${rc}"
}

run_record "docker version" docker version

if [[ "${job}" == "kind" ]]; then
  run_record "kind version" kind version
  run_record "kind node image" docker inspect unix-lessons-control-plane --format '{{.Config.Image}}'
  image_ref=$(docker inspect unix-lessons-control-plane --format '{{.Config.Image}}')
  run_record "kind node image digests" \
    docker image inspect "${image_ref}" --format '{{json .RepoTags}}{{"\n"}}{{json .RepoDigests}}'
  run_record "kubectl version" kubectl version
fi
