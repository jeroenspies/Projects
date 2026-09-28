#!/usr/bin/env bash
# Apply the research snippets and record what the API and kubelet actually do.
# Hard failures of the working demos live in the pair scripts. This script fails
# only when it cannot finish the observation.
set -euo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/scripts/lib.sh
source "${DIR}/scripts/lib.sh"

SNIP="${DIR}/snippets"
report=$(mktemp)

note() {
  printf '%s\n' "$1" | tee -a "${report}"
}

capture() {
  local title="$1"
  shift
  local log rc
  log=$(mktemp)
  set +e
  "$@" >"${log}" 2>&1
  rc=$?
  set -e
  note "### ${title}"
  note ""
  note "Command: \`$*\`"
  note ""
  note "Exit ${rc}."
  note ""
  note '```'
  sed -n '1,40p' "${log}" >> "${report}"
  note '```'
  note ""
  LAST_RC=$rc
  LAST_LOG=$log
}

pod_snapshot() {
  local ns="$1"
  local name="$2"
  kubectl get pod -n "$ns" "$name" -o jsonpath='phase={.status.phase} reason={.status.reason} waiting={.status.containerStatuses[0].state.waiting.reason} message={.status.containerStatuses[0].state.waiting.message}{"\n"}' \
    2>/dev/null || echo "pod ${ns}/${name} not found"
}

summary "## Snippet validation"
summary_blank

require_kind_context

capture "Namespace snippet" kubectl apply -f "${SNIP}/namespace-team-a.yaml"
[[ "$LAST_RC" -eq 0 ]] || fail "namespace snippet was rejected"

capture "developer-readonly Role" kubectl apply -f "${SNIP}/role-developer-readonly.yaml"
[[ "$LAST_RC" -eq 0 ]] || fail "developer-readonly Role was rejected"

capture "restricted pod snippet" kubectl apply -f "${SNIP}/restricted-pod.yaml"
note "Pod status while waiting for the kubelet:"
note ""
for _ in $(seq 1 20); do
  snap=$(pod_snapshot team-a restricted-snippet)
  note "- ${snap}"
  if printf '%s' "$snap" | grep -E -q 'CreateContainerConfigError|CrashLoopBackOff|Running|ImagePull|ErrImage|Forbidden'; then
    break
  fi
  sleep 3
done
note ""
note "Describe (tail):"
note ""
note '```'
kubectl describe pod -n team-a restricted-snippet 2>&1 | tail -n 40 >> "${report}" || true
note '```'
note ""
kubectl delete pod -n team-a restricted-snippet --wait=false --ignore-not-found >/dev/null

capture "ValidatingAdmissionPolicy object" kubectl apply -f "${SNIP}/vap.yaml"
[[ "$LAST_RC" -eq 0 ]] || fail "ValidatingAdmissionPolicy object was rejected"
note "No binding is applied here. pair2 shows that the unbound policy does not reject pods."
note ""

capture "CronJob snippet before ServiceAccount and ConfigMap exist" \
  kubectl apply -f "${SNIP}/cronjob.yaml"
note "Creating a Job from that CronJob:"
note ""
kubectl delete job -n team-a snippet-cron --ignore-not-found >/dev/null
set +e
kubectl create job -n team-a snippet-cron --from=cronjob/nightly-report >"${LAST_LOG}.job" 2>&1
job_rc=$?
set -e
note "kubectl create job exit ${job_rc}."
note '```'
sed -n '1,30p' "${LAST_LOG}.job" >> "${report}"
note '```'
note ""
if [[ "$job_rc" -eq 0 ]]; then
  for _ in $(seq 1 15); do
    snap=$(kubectl get pods -n team-a -l job-name=snippet-cron -o jsonpath='{range .items[*]}{.metadata.name} {.status.phase} {.status.containerStatuses[0].state.waiting.reason} {.status.containerStatuses[0].state.waiting.message}{"\n"}{end}' 2>/dev/null || true)
    note "- ${snap:-no pod yet}"
    if printf '%s' "$snap" | grep -E -q 'Error|BackOff|Running|Completed|Forbidden|Image'; then
      break
    fi
    sleep 3
  done
  note ""
  note '```'
  kubectl describe job -n team-a snippet-cron 2>&1 | tail -n 30 >> "${report}" || true
  note '```'
  note ""
fi
kubectl delete job -n team-a snippet-cron --ignore-not-found >/dev/null
kubectl delete cronjob -n team-a nightly-report --ignore-not-found >/dev/null

note "### Retry with the named ServiceAccount and ConfigMap"
note ""
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: report-runner
  namespace: team-a
automountServiceAccountToken: false
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: report-script-v7
  namespace: team-a
data:
  run.sh: |
    #!/bin/sh
    echo SCRIPT_VERSION=snippet
EOF
capture "CronJob snippet after ServiceAccount and ConfigMap exist" \
  kubectl apply -f "${SNIP}/cronjob.yaml"
kubectl delete job -n team-a snippet-cron --ignore-not-found >/dev/null
set +e
kubectl create job -n team-a snippet-cron --from=cronjob/nightly-report > /tmp/snippet-job.txt 2>&1
create_rc=$?
set -e
note "Second kubectl create job exit ${create_rc}."
note '```'
sed -n '1,30p' /tmp/snippet-job.txt >> "${report}"
note '```'
note ""
note "Waiting for the Job's pod to show a terminal observation:"
note ""
for _ in $(seq 1 25); do
  snap=$(kubectl get pods -n team-a -l job-name=snippet-cron -o jsonpath='{range .items[*]}{.metadata.name} phase={.status.phase} waiting={.status.containerStatuses[0].state.waiting.reason} message={.status.containerStatuses[0].state.waiting.message}{"\n"}{end}' 2>/dev/null || true)
  note "- ${snap:-no pod yet}"
  if printf '%s' "$snap" | grep -E -q 'CreateContainerConfigError|CrashLoopBackOff|Error|Completed|Running|ImagePull|ErrImage|Forbidden'; then
    if ! printf '%s' "$snap" | grep -q 'ContainerCreating'; then
      break
    fi
  fi
  sleep 3
done
note ""
note '```'
kubectl describe pods -n team-a -l job-name=snippet-cron 2>&1 | tail -n 50 >> "${report}" || true
note '```'
note ""
note "Pod logs, if any:"
note '```'
kubectl logs -n team-a -l job-name=snippet-cron --all-containers --tail=20 >> "${report}" 2>&1 || true
note '```'
note ""

kubectl delete job -n team-a snippet-cron --ignore-not-found >/dev/null
kubectl delete cronjob -n team-a nightly-report --ignore-not-found >/dev/null

summary_file "${report}"
summary_blank
summary "Snippet observation finished. See YAML_VALIDATION.md for the interpreted result."
summary_blank
