#!/usr/bin/env bash
# Show PSA baseline and restricted rejecting a docker.sock hostPath. Server dry-run only.
set -euo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "${DIR}/.." && pwd)
# shellcheck source=SCRIPTDIR/../scripts/lib.sh
source "${ROOT}/scripts/lib.sh"

summary_open pair4-pod-security
transcript "## Pair 4: socket hostPath admission"
transcript_blank

summary "## Pair 4: socket hostPath admission"
summary_blank

require_kind_context

expect_ok "socket namespaces" kubectl apply -f "${DIR}/manifests/namespaces.yaml"

reject_socket() {
  local ns="$1"
  expect_denied 'hostPath|PodSecurity|baseline|restricted' \
    "docker.sock hostPath in ${ns}" \
    kubectl apply --dry-run=server -n "$ns" -f "${DIR}/manifests/socket-pod.yaml"
  transcript_cmd_result "Pod Security ${ns}" "${LAST_CMD}" "${DENIED_LOG}" "${DENIED_RC}"
  if kubectl get pod -n "$ns" docker-socket >/dev/null 2>&1; then
    kubectl delete pod -n "$ns" docker-socket --wait=false
    fail "docker-socket pod was created in ${ns}"
  fi
}

reject_socket socket-baseline
reject_socket socket-restricted
summary "Both dry-runs were rejected and no socket pod was stored."
summary_blank
summary "Pair 4 Kubernetes assertions passed."
summary_blank
