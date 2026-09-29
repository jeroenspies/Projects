#!/usr/bin/env bash
# Record the CI runner. This goes to the job summary, not to RESULTS.md.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "${script_dir}/.." && pwd)
# shellcheck source=SCRIPTDIR/lib.sh
source "${root}/scripts/lib.sh"

summary "## Runner"
summary_blank
{
  printf -- '- date: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf -- '- uname: %s\n' "$(uname -a)"
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf -- '- os: %s\n' "${PRETTY_NAME:-unknown}"
  fi
  if command -v docker >/dev/null 2>&1; then
    printf -- '- docker server: %s\n' "$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo unknown)"
  fi
  if command -v kubectl >/dev/null 2>&1; then
    printf -- '- kubectl: %s\n' "$(kubectl version --client=true 2>/dev/null | tr '\n' ' ')"
  fi
  if command -v kind >/dev/null 2>&1; then
    printf -- '- kind: %s\n' "$(kind version 2>/dev/null | tr '\n' ' ')"
  fi
  node="${KIND_CLUSTER_NAME}-control-plane"
  if command -v docker >/dev/null 2>&1 && docker inspect "${node}" >/dev/null 2>&1; then
    printf -- '- kind node privileged: %s\n' "$(docker inspect "${node}" --format '{{.HostConfig.Privileged}}')"
    printf -- '- kind node image: %s\n' "$(docker inspect "${node}" --format '{{.Config.Image}}')"
  fi
} > /tmp/logs-pi-runner.md
summary_file() {
  local file="$1"
  [[ -f "$file" ]] || fail "missing summary file: $file"
  cat "$file"
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    cat "$file" >> "${GITHUB_STEP_SUMMARY}"
  fi
}
summary_file /tmp/logs-pi-runner.md
summary_blank
