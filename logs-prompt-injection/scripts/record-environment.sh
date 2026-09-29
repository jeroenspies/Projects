#!/usr/bin/env bash
# Write tool versions into summaries/environment-kind.md.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "${script_dir}/.." && pwd)
# shellcheck source=SCRIPTDIR/lib.sh
source "${ROOT}/scripts/lib.sh"

summary_open "environment-kind"
transcript "## Omgeving (kind)"
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

node="${KIND_CLUSTER_NAME}-control-plane"
run_record "docker version" docker version
run_record "kind version" kind version
run_record "kind node image" docker inspect "${node}" --format '{{.Config.Image}}'
image_ref=$(docker inspect "${node}" --format '{{.Config.Image}}')
run_record "kind node image digests" \
  docker image inspect "${image_ref}" --format '{{json .RepoTags}}{{"\n"}}{{json .RepoDigests}}'
run_record "kubectl version" kubectl version
run_record "cni images" \
  kubectl -n kube-system get ds,deploy \
  -o jsonpath='{range .items[*]}{.kind}{"/"}{.metadata.name}{" "}{range .spec.template.spec.containers[*]}{.image}{" "}{end}{"\n"}{end}'
