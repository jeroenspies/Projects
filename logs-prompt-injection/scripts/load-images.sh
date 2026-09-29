#!/usr/bin/env bash
# Pull the pinned app images and load them into the kind node.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "${script_dir}/.." && pwd)
# shellcheck source=SCRIPTDIR/lib.sh
source "${root}/scripts/lib.sh"

pull_and_check() {
  local ref="$1"
  local index_digest="$2"
  local amd64_digest="$3"
  local attempt
  for attempt in 1 2 3; do
    if docker pull "${ref}"; then
      break
    fi
    if [[ "${attempt}" -eq 3 ]]; then
      printf 'docker pull failed: %s\n' "${ref}" >&2
      exit 1
    fi
    sleep 5
  done
  local repos
  repos=$(docker image inspect "${ref}" --format '{{json .RepoDigests}}')
  printf 'RepoDigests %s %s\n' "${ref}" "${repos}"
  case "${repos}" in
    *"${index_digest}"* | *"${amd64_digest}"*) ;;
    *)
      printf 'digest pin mismatch for %s\nexpected index %s or amd64 %s\ngot %s\n' \
        "${ref}" "${index_digest}" "${amd64_digest}" "${repos}" >&2
      exit 1
      ;;
  esac
  kind load docker-image "${ref}" --name "${KIND_CLUSTER_NAME}"
}

pull_and_check "${NGINX_REF}" "${NGINX_DIGEST}" "${NGINX_AMD64_DIGEST}"
pull_and_check "${PYTHON_REF}" "${PYTHON_DIGEST}" "${PYTHON_AMD64_DIGEST}"
