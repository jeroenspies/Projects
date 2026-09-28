#!/usr/bin/env bash
# Pair 2 on kind: PSA rejection, RBAC before/after, Deployment vs pods, and VAP.
# Privileged pods are submitted only where admission must reject them. They are not started.
set -euo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "${DIR}/.." && pwd)
# shellcheck source=SCRIPTDIR/../scripts/lib.sh
source "${ROOT}/scripts/lib.sh"

MAN="${DIR}/manifests"
SNIP="${ROOT}/snippets"

summary_open pair2-rbac-admission
transcript "## Pair 2: RBAC and admission"
transcript_blank

summary "## Pair 2: RBAC and admission"
summary_blank

require_kind_context

expect_ok "namespace team-a" kubectl apply -f "${SNIP}/namespace-team-a.yaml"
expect_ok "service accounts" kubectl apply -f "${MAN}/serviceaccounts.yaml"

summary "### Privileged pod in a restricted namespace"
summary_blank
expect_denied 'PodSecurity|restricted|privileged' \
  "privileged pod" \
  kubectl apply -f "${MAN}/privileged-pod.yaml"
transcript_block "Pod Security" "${LAST_CMD}" "${DENIED_LOG}"
if kubectl get pod -n team-a privileged-rejected >/dev/null 2>&1; then
  kubectl delete pod -n team-a privileged-rejected --wait=false
  fail "privileged pod object exists after a rejected apply"
fi
summary "No privileged pod object was stored."
summary_blank

summary "### kubectl auth can-i create pods"
summary_blank
before_create=$(can_i create pods -n team-a --as=dev-user)
before_secrets=$(can_i get secrets -n team-a --as=dev-user)
[[ "$before_create" == "no" ]] || fail "dev-user could create pods before a binding (${before_create})"
[[ "$before_secrets" == "no" ]] || fail "dev-user could get secrets before a binding"

expect_ok "pod-creator Role" kubectl apply -f "${MAN}/role-pod-creator.yaml"
expect_ok "pod-creator RoleBinding" kubectl apply -f "${MAN}/rolebinding-pod-creator.yaml"

after_create=$(can_i create pods -n team-a --as=dev-user)
after_secrets=$(can_i get secrets -n team-a --as=dev-user)
after_get_pods=$(can_i get pods -n team-a --as=dev-user)
[[ "$after_create" == "yes" ]] || fail "dev-user cannot create pods after the binding (${after_create})"
[[ "$after_secrets" == "no" ]] || fail "pod-creator Role granted get secrets"
[[ "$after_get_pods" == "no" ]] || fail "pod-creator Role granted get pods"

summary "| Check | Before RoleBinding | After RoleBinding |"
summary "| --- | --- | --- |"
summary "| \`create pods\` as dev-user | ${before_create} | ${after_create} |"
summary "| \`get secrets\` as dev-user | ${before_secrets} | ${after_secrets} |"
summary "| \`get pods\` as dev-user | no | ${after_get_pods} |"
summary_blank
transcript "### create pods as dev-user"
transcript_blank
transcript "| Check | Before RoleBinding | After RoleBinding |"
transcript "| --- | --- | --- |"
transcript "| \`create pods\` as dev-user | ${before_create} | ${after_create} |"
transcript "| \`get secrets\` as dev-user | ${before_secrets} | ${after_secrets} |"
transcript "| \`get pods\` as dev-user | no | ${after_get_pods} |"
transcript_blank

summary "### developer-readonly Role"
summary_blank
expect_ok "developer-readonly Role" kubectl apply -f "${SNIP}/role-developer-readonly.yaml"
expect_ok "reader RoleBinding" kubectl apply -f "${MAN}/rolebinding-reader.yaml"
reader_get=$(capture_can_i "can-i get pods as reader" get pods -n team-a --as=reader)
reader_list=$(capture_can_i "can-i list deployments as reader" list deployments -n team-a --as=reader)
reader_logs=$(capture_can_i "can-i get pods/log as reader" get pods/log -n team-a --as=reader)
reader_create=$(capture_can_i "can-i create pods as reader" create pods -n team-a --as=reader)
reader_secrets=$(capture_can_i "can-i get secrets as reader" get secrets -n team-a --as=reader)
reader_patch=$(capture_can_i "can-i patch configmaps as reader" patch configmaps -n team-a --as=reader)
reader_exec=$(capture_can_i "can-i create pods/exec as reader" create pods/exec -n team-a --as=reader)
[[ "$reader_get" == "yes" ]] || fail "reader cannot get pods"
[[ "$reader_list" == "yes" ]] || fail "reader cannot list deployments"
[[ "$reader_logs" == "yes" ]] || fail "reader cannot get pod logs"
[[ "$reader_create" == "no" ]] || fail "reader can create pods"
[[ "$reader_secrets" == "no" ]] || fail "reader can get secrets"
[[ "$reader_patch" == "no" ]] || fail "reader can patch configmaps"
[[ "$reader_exec" == "no" ]] || fail "reader can create pods/exec"
summary "| Check as reader | Result |"
summary "| --- | --- |"
summary "| get pods | ${reader_get} |"
summary "| list deployments | ${reader_list} |"
summary "| get pods/log | ${reader_logs} |"
summary "| create pods | ${reader_create} |"
summary "| get secrets | ${reader_secrets} |"
summary "| patch configmaps | ${reader_patch} |"
summary "| create pods/exec | ${reader_exec} |"
summary_blank

summary "### Deployment accepted, pods not created"
summary_blank
expect_ok "noncompliant Deployment" kubectl apply -f "${MAN}/deployment-noncompliant.yaml"
if ! grep -E -q 'Warning:|PodSecurity|restricted' "${OK_LOG}"; then
  cat "${OK_LOG}" >&2
  fail "applying the noncompliant Deployment did not produce a PSA warning"
fi
transcript_cmd_result "noncompliant Deployment" "${LAST_CMD}" "${OK_LOG}" "0"
summary "Apply output:"
summary '```'
sed -n '1,25p' "${OK_LOG}" | while IFS= read -r line; do
  summary "$line"
done
summary '```'
summary_blank

found_event=no
event_line=""
event_log=$(mktemp)
event_raw=$(mktemp)
event_rc=0
event_jsonpath='{range .items[*]}{.involvedObject.kind}{" "}{.involvedObject.name}{" "}{.reason}{" "}{.message}{"\n"}{end}'
event_kubectl=(
  kubectl get events -n team-a
  --field-selector 'reason=FailedCreate,involvedObject.kind=ReplicaSet'
  -o "jsonpath=${event_jsonpath}"
)
event_cmd="$(format_cmd "${event_kubectl[@]}") | grep '^ReplicaSet noncompliant-'"
for _ in $(seq 1 30); do
  set +e
  "${event_kubectl[@]}" >"${event_raw}" 2>&1
  event_rc=$?
  set -e
  if [[ "$event_rc" -ne 0 ]]; then
    cp "${event_raw}" "${event_log}"
  else
    grep '^ReplicaSet noncompliant-' "${event_raw}" >"${event_log}" || true
  fi
  event_line=$(grep -E 'PodSecurity|restricted|privileged' "${event_log}" | head -n 1 || true)
  if [[ -n "$event_line" ]]; then
    found_event=yes
    break
  fi
  sleep 2
done
pods_out=$(mktemp)
pods_err=$(mktemp)
pods_file=$(mktemp)
pods_cmd=$(format_cmd kubectl get pods -n team-a -l app=noncompliant --no-headers)
set +e
kubectl get pods -n team-a -l app=noncompliant --no-headers >"${pods_out}" 2>"${pods_err}"
pods_rc=$?
set -e
pod_count=$(wc -l < "${pods_out}" | tr -d ' ')
cat "${pods_out}" "${pods_err}" > "${pods_file}"
ready_file=$(mktemp)
ready_cmd=$(format_cmd kubectl get deploy -n team-a noncompliant -o 'jsonpath={.status.readyReplicas}')
set +e
kubectl get deploy -n team-a noncompliant -o 'jsonpath={.status.readyReplicas}' >"${ready_file}" 2>&1
ready_rc=$?
set -e
ready=$(tr -d '[:space:]' < "${ready_file}")
[[ "$pod_count" == "0" ]] || fail "noncompliant Deployment created ${pod_count} pod(s)"
[[ "$ready_rc" -eq 0 ]] || fail "reading readyReplicas exited ${ready_rc}"
[[ -z "$ready" || "$ready" == "0" ]] || fail "noncompliant Deployment has readyReplicas=${ready}"
[[ "$found_event" == "yes" ]] || fail "no ReplicaSet/pod event mentioned PodSecurity"
transcript_cmd_result "ReplicaSet event" "${event_cmd}" "${event_log}" "${event_rc}"
transcript_cmd_result "noncompliant pods" "${pods_cmd}" "${pods_file}" "${pods_rc}"
transcript_cmd_result "readyReplicas" "${ready_cmd}" "${ready_file}" "${ready_rc}"
summary "Pods with label app=noncompliant: ${pod_count}. readyReplicas: ${ready:-0}."
summary "Event: \`${event_line}\`"
summary_blank

summary "### create pods can select another ServiceAccount"
summary_blank
# The policy object may already exist from snippet validation. Without a binding it does not enforce.
kubectl delete validatingadmissionpolicybinding pods-only-own-serviceaccount --ignore-not-found
# create, not apply: kubectl apply GETs the pod first, and this Role cannot get pods.
expect_ok "other-sa pod before the binding" \
  kubectl create -f "${MAN}/pod-other-sa.yaml" --as=dev-user
transcript_cmd_result "other-sa before the binding" "${LAST_CMD}" "${OK_LOG}" "0"
sa_name=$(kubectl get pod -n team-a use-other-sa -o jsonpath='{.spec.serviceAccountName}')
[[ "$sa_name" == "other-sa" ]] || fail "pod service account was ${sa_name}"
if ! kubectl wait -n team-a --for=condition=Ready pod/use-other-sa --timeout=180s; then
  kubectl describe pod -n team-a use-other-sa || true
  fail "other-sa pod did not become Ready"
fi
summary "dev-user (create pods only) started a restricted pod with serviceAccountName=other-sa."
summary_blank
kubectl delete pod -n team-a use-other-sa --wait=true

summary "### ValidatingAdmissionPolicy"
summary_blank
expect_ok "ValidatingAdmissionPolicy" kubectl apply -f "${SNIP}/vap.yaml"
# Re-create once more so the summary shows the object alone still allows the request.
expect_ok "other-sa pod while the policy is unbound" \
  kubectl create -f "${MAN}/pod-other-sa.yaml" --as=dev-user
transcript_cmd_result "other-sa before the binding, policy unbound" "${LAST_CMD}" "${OK_LOG}" "0"
kubectl delete pod -n team-a use-other-sa --wait=true
summary "The policy object alone did not reject the pod. The sketch has no binding."
summary_blank

expect_ok "ValidatingAdmissionPolicyBinding" kubectl apply -f "${SNIP}/vap-binding.yaml"
denied=no
other_cmd=$(format_cmd kubectl create -f "${MAN}/pod-other-sa.yaml" --as=dev-user)
vap_log=$(mktemp)
for _ in $(seq 1 8); do
  vap_log=$(mktemp)
  set +e
  kubectl create -f "${MAN}/pod-other-sa.yaml" --as=dev-user 2>&1 | tee "${vap_log}" >/dev/null
  vap_rc=${PIPESTATUS[0]}
  set -e
  if [[ "$vap_rc" -ne 0 ]] && grep -E -q 'pods-only-own-serviceaccount|ValidatingAdmissionPolicy' "${vap_log}"; then
    denied=yes
    transcript_cmd_result "other-sa after the binding" "${other_cmd}" "${vap_log}" "${vap_rc}"
    summary "Denied: other-sa pod after the binding (exit ${vap_rc})"
    summary '```'
    sed -n '1,30p' "${vap_log}" | while IFS= read -r line; do
      summary "$line"
    done
    summary '```'
    summary_blank
    break
  fi
  kubectl delete pod -n team-a use-other-sa --wait=true --ignore-not-found >/dev/null
  sleep 2
done
if [[ "$denied" != "yes" ]]; then
  transcript_cmd_result "other-sa after the binding" "${other_cmd}" "${vap_log}" "${vap_rc}"
  fail "binding did not reject the other-sa pod"
fi
if kubectl get pod -n team-a use-other-sa >/dev/null 2>&1; then
  kubectl delete pod -n team-a use-other-sa --wait=false
  fail "other-sa pod exists after the policy denied it"
fi

expect_ok "app service account pod after the binding" \
  kubectl create -f "${MAN}/pod-app-sa.yaml" --as=dev-user
transcript_cmd_result "app service account pod" "${LAST_CMD}" "${OK_LOG}" "0"
app_sa=$(kubectl get pod -n team-a use-app-sa -o jsonpath='{.spec.serviceAccountName}')
[[ "$app_sa" == "app" ]] || fail "allowed pod used service account ${app_sa}"
transcript_exec "serviceAccountName of the accepted pod" \
  kubectl get pod -n team-a use-app-sa -o jsonpath='{.spec.serviceAccountName}'
summary "A pod using service account \`app\` is still accepted."
summary_blank

expect_ok "namespace team-b" kubectl apply -f "${MAN}/namespace-team-b.yaml"
expect_ok "team-b service account" kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: other-sa
  namespace: team-b
automountServiceAccountToken: false
EOF
# dev-user's RoleBinding is only in team-a. The admin apply shows the policy binding
# does not select team-b.
team_b_user=$(capture_can_i "can-i create pods in team-b as dev-user" create pods -n team-b --as=dev-user)
[[ "$team_b_user" == "no" ]] || fail "dev-user can create pods in team-b"
expect_ok "admin creates other-sa pod in team-b" \
  kubectl apply -f "${MAN}/pod-other-sa-team-b.yaml"
transcript_cmd_result "admin creates other-sa pod in team-b" "${LAST_CMD}" "${OK_LOG}" "0"
summary "dev-user create pods in team-b: ${team_b_user}. The same pod shape is accepted in team-b because the binding's namespace selector is team-a only."
summary_blank

summary "Pair 2 Kubernetes assertions passed."
summary_blank
