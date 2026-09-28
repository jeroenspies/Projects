#!/usr/bin/env bash
# Pair 3 on kind: a restricted CronJob runs a ConfigMap script that a patch-only user can change.
# The fixed copy uses an immutable ConfigMap and a digest-pinned image.
set -euo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "${DIR}/.." && pwd)
# shellcheck source=SCRIPTDIR/../scripts/lib.sh
source "${ROOT}/scripts/lib.sh"

MAN="${DIR}/manifests"

summary_open pair3-configmap
transcript "## Pair 3: ConfigMap script and image reference"
transcript_blank

summary "## Pair 3: ConfigMap script and image reference"
summary_blank

grep -q 'docker.io/library/busybox:1.37.0' "${MAN}/cronjob.yaml"
grep -q "${BUSYBOX_DIGEST}" "${MAN}/cronjob-fixed.yaml"
if grep -q '@sha256:' "${MAN}/cronjob.yaml"; then
  fail "mutable CronJob should use a tag, not a digest"
fi

require_kind_context

expect_ok "namespace reports" kubectl apply -f "${MAN}/namespace-reports.yaml"
expect_ok "report-runner ServiceAccount" kubectl apply -f "${MAN}/serviceaccount.yaml"
expect_ok "mutable ConfigMap" kubectl apply -f "${MAN}/configmap.yaml"
expect_ok "mutable CronJob" kubectl apply -f "${MAN}/cronjob.yaml"
expect_ok "configmap-patcher Role" kubectl apply -f "${MAN}/role-configmap-patcher.yaml"
expect_ok "cm-editor RoleBinding" kubectl apply -f "${MAN}/rolebinding-configmap-patcher.yaml"

patch_yes=$(can_i patch configmaps -n reports --as=cm-editor)
get_no=$(can_i get configmaps -n reports --as=cm-editor)
update_no=$(can_i update configmaps -n reports --as=cm-editor)
[[ "$patch_yes" == "yes" ]] || fail "cm-editor cannot patch configmaps"
[[ "$get_no" == "no" ]] || fail "cm-editor can get configmaps"
[[ "$update_no" == "no" ]] || fail "cm-editor can update configmaps"
summary "| cm-editor | Result |"
summary "| --- | --- |"
summary "| patch configmaps | ${patch_yes} |"
summary "| get configmaps | ${get_no} |"
summary "| update configmaps | ${update_no} |"
summary_blank
transcript "### can-i as cm-editor"
transcript_blank
transcript "| cm-editor | Result |"
transcript "| --- | --- |"
transcript "| patch configmaps | ${patch_yes} |"
transcript "| get configmaps | ${get_no} |"
transcript "| update configmaps | ${update_no} |"
transcript_blank

run_from_cronjob() {
  local job="$1"
  local cron="$2"
  local logf cmd_s logs_rc
  kubectl delete job -n reports "$job" --ignore-not-found >/dev/null
  kubectl create job -n reports "$job" --from="cronjob/${cron}" >/dev/null
  if ! kubectl wait -n reports --for=condition=complete "job/${job}" --timeout=180s >/dev/null; then
    kubectl describe "job/${job}" -n reports >&2 || true
    kubectl get pods -n reports -l "job-name=${job}" -o wide >&2 || true
    kubectl describe pods -n reports -l "job-name=${job}" >&2 || true
    kubectl logs -n reports -l "job-name=${job}" --all-containers >&2 || true
    logf=$(mktemp)
    cmd_s=$(format_cmd kubectl logs -n reports "job/${job}")
    set +e
    kubectl logs -n reports "job/${job}" 2>&1 | tee "${logf}" >/dev/null
    set -e
    transcript_block "SCRIPT_VERSION ${job#version-}" "${cmd_s}" "${logf}"
    fail "job ${job} did not complete"
  fi
  logf=$(mktemp)
  cmd_s=$(format_cmd kubectl logs -n reports "job/${job}")
  set +e
  kubectl logs -n reports "job/${job}" 2>&1 | tee "${logf}" >/dev/null
  logs_rc=${PIPESTATUS[0]}
  set -e
  transcript_block "SCRIPT_VERSION ${job#version-}" "${cmd_s}" "${logf}"
  if [[ "${logs_rc}" -ne 0 ]]; then
    fail "kubectl logs for job ${job} exited ${logs_rc}"
  fi
  cat "${logf}"
}

logs_one=$(run_from_cronjob version-one nightly-report)
printf '%s\n' "$logs_one" | grep -q 'SCRIPT_VERSION=one' || fail "first run did not print SCRIPT_VERSION=one: ${logs_one}"

# kubectl patch GETs the object before sending PATCH, so a patch-only user is
# rejected by the client. The API itself is called with Impersonate-User and no GET.
cli_log=$(mktemp)
set +e
kubectl patch configmap report-script -n reports --as=cm-editor --type=merge \
  --patch '{"data":{"run.sh":"#!/bin/sh\necho SCRIPT_VERSION=cli\n"}}' >"${cli_log}" 2>&1
cli_rc=$?
set -e
summary "\`kubectl patch --as=cm-editor\` (client GETs first) exit ${cli_rc}:"
summary '```'
sed -n '1,20p' "${cli_log}" | while IFS= read -r line; do
  summary "$line"
done
summary '```'
summary_blank
cli_cmd=$(format_cmd kubectl patch configmap report-script -n reports --as=cm-editor --type=merge \
  --patch '{"data":{"run.sh":"#!/bin/sh\necho SCRIPT_VERSION=cli\n"}}')
transcript_block "kubectl patch --as=cm-editor" "${cli_cmd}" "${cli_log}"
transcript "Exit ${cli_rc}."
transcript_blank

body=$(mktemp)
cat >"${body}" <<'EOF'
{"data":{"run.sh":"#!/bin/sh\necho SCRIPT_VERSION=two\n"}}
EOF
expect_ok "API merge-patch as cm-editor" \
  api_patch_as cm-editor reports report-script "${body}"
summary "The patch request did not GET the ConfigMap. cm-editor's patch verb was enough."
summary_blank
transcript_block "API merge-patch as cm-editor" "$(cat /tmp/unix-lessons/api-patch.cmd)" "${OK_LOG}"
transcript "HTTP $(cat /tmp/unix-lessons/api-patch.http)."
transcript_blank

logs_two=$(run_from_cronjob version-two nightly-report)
printf '%s\n' "$logs_two" | grep -q 'SCRIPT_VERSION=two' || fail "second run did not print SCRIPT_VERSION=two: ${logs_two}"

expect_ok "immutable ConfigMap" kubectl apply -f "${MAN}/configmap-immutable.yaml"
immutable_body=$(mktemp)
printf '%s\n' '{"data":{"run.sh":"#!/bin/sh\necho SCRIPT_VERSION=hacked\n"}}' >"${immutable_body}"
expect_denied 'immutable' "admin patch of immutable ConfigMap" \
  kubectl patch configmap report-script-v7 -n reports --type=merge --patch-file "${immutable_body}"
transcript_block "admin patch of immutable ConfigMap" "${LAST_CMD}" "${DENIED_LOG}"
expect_denied 'immutable' "cm-editor API patch of immutable ConfigMap" \
  api_patch_as cm-editor reports report-script-v7 "${immutable_body}"
transcript_block "cm-editor API patch of immutable ConfigMap" "$(cat /tmp/unix-lessons/api-patch.cmd)" "${DENIED_LOG}"
transcript "HTTP $(cat /tmp/unix-lessons/api-patch.http)."
transcript_blank

expect_ok "fixed CronJob" kubectl apply -f "${MAN}/cronjob-fixed.yaml"
image_log=$(mktemp)
fixed_image=$(kubectl get cronjob -n reports nightly-report-fixed -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}' | tee "${image_log}")
transcript_block "version-seven image" \
  "$(format_cmd kubectl get cronjob -n reports nightly-report-fixed -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}')" \
  "${image_log}"
mutable_image=$(kubectl get cronjob -n reports nightly-report -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}')
sa_name=$(kubectl get cronjob -n reports nightly-report-fixed -o jsonpath='{.spec.jobTemplate.spec.template.spec.serviceAccountName}')
automount=$(kubectl get cronjob -n reports nightly-report-fixed -o jsonpath='{.spec.jobTemplate.spec.template.spec.automountServiceAccountToken}')
cm_name=$(kubectl get cronjob -n reports nightly-report-fixed -o jsonpath='{.spec.jobTemplate.spec.template.spec.volumes[0].configMap.name}')
[[ "$fixed_image" == "${BUSYBOX_IMAGE}" ]] || fail "fixed image is ${fixed_image}"
[[ "$mutable_image" == "${BUSYBOX_TAG}" ]] || fail "mutable image is ${mutable_image}"
[[ "$sa_name" == "report-runner" ]] || fail "fixed service account is ${sa_name}"
[[ "$automount" == "false" ]] || fail "automountServiceAccountToken is ${automount}"
[[ "$cm_name" == "report-script-v7" ]] || fail "fixed configmap is ${cm_name}"

logs_seven=$(run_from_cronjob version-seven nightly-report-fixed)
printf '%s\n' "$logs_seven" | grep -q 'SCRIPT_VERSION=seven' || fail "fixed run did not print SCRIPT_VERSION=seven: ${logs_seven}"

summary "| Run | Image reference | ConfigMap | Log |"
summary "| --- | --- | --- | --- |"
summary "| version-one | \`${mutable_image}\` | report-script (mutable) | \`SCRIPT_VERSION=one\` |"
summary "| version-two | \`${mutable_image}\` | report-script after patch | \`SCRIPT_VERSION=two\` |"
summary "| version-seven | \`${fixed_image}\` | report-script-v7 immutable | \`SCRIPT_VERSION=seven\` |"
summary_blank
summary "A new Job was created for each run, so this does not wait for the kubelet ConfigMap sync period. The tag was not moved in a registry; the fix is the digest in the CronJob spec. hostPath is not used."
summary_blank
summary "Pair 3 Kubernetes assertions passed."
summary_blank
