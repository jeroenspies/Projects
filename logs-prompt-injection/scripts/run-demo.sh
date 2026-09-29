#!/usr/bin/env bash
# Indirect prompt injection via pod logs, on a throw-away kind cluster.
# The marker is test data. This script never treats it as an instruction.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "${script_dir}/.." && pwd)
# shellcheck source=SCRIPTDIR/lib.sh
source "${ROOT}/scripts/lib.sh"

require_kind_context

NODE="${KIND_CLUSTER_NAME}-control-plane"
BASELINE_BLOCKED=no
FAKE_IP=""
API_IP=""
API_PORT=""
EP_IP=""
EP_PORT=""

apply_ok() {
  local heading="$1"
  shift
  transcript_exec "${heading}" "$@"
  [[ "${TRANSCRIPT_RC}" -eq 0 ]] || fail "${heading} failed"
}

apply_configmap() {
  local heading="$1"
  local ns="$2"
  local name="$3"
  shift 3
  local log rc cmd_s
  cmd_s=$(format_cmd kubectl create configmap "${name}" -n "${ns}" --dry-run=client -o yaml "$@")
  cmd_s="${cmd_s} | kubectl apply -f -"
  log=$(mktemp)
  set +e
  kubectl create configmap "${name}" -n "${ns}" --dry-run=client -o yaml "$@" | kubectl apply -f - >"${log}" 2>&1
  rc=$?
  set -e
  transcript_cmd_result "${heading}" "${cmd_s}" "${log}" "${rc}"
  [[ "${rc}" -eq 0 ]] || fail "${heading} failed"
}

wait_ready() {
  local ns="$1"
  local pod="$2"
  if ! kubectl wait -n "${ns}" --for=condition=Ready "pod/${pod}" --timeout=180s; then
    kubectl describe pod -n "${ns}" "${pod}" >&2 || true
    kubectl logs -n "${ns}" "${pod}" --all-containers >&2 || true
    fail "pod ${ns}/${pod} did not become Ready"
  fi
}

cluster_ip() {
  local ns="$1"
  local name="$2"
  local ip="" attempt
  for attempt in $(seq 1 30); do
    ip=$(kubectl get svc "${name}" -n "${ns}" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)
    if [[ -n "${ip}" && "${ip}" != "None" ]]; then
      printf '%s' "${ip}"
      return 0
    fi
    sleep 1
  done
  return 1
}

assert_audit() {
  transcript_exec "apiserver audit flags" \
    docker exec "${NODE}" grep audit /etc/kubernetes/manifests/kube-apiserver.yaml
  [[ "${TRANSCRIPT_RC}" -eq 0 ]] || fail "audit flags missing from the apiserver manifest"
  assert_file_contains "${TRANSCRIPT_LOG}" "--audit-policy-file=" "audit-policy-file flag missing"
  transcript_exec "audit policy on the node" \
    docker exec "${NODE}" cat /etc/kubernetes/policies/audit-policy.yaml
  [[ "${TRANSCRIPT_RC}" -eq 0 ]] || fail "audit policy file is not mounted in the kind node"
}

probe_until() {
  local heading="$1"
  local ns="$2"
  local ip="$3"
  local want="$4"
  local log decisive_log cmd_s rc attempt decisive_rc
  log=$(mktemp)
  decisive_log=$(mktemp)
  cmd_s=$(format_cmd kubectl exec -n "${ns}" egress-probe -- python /opt/probe.py "http://${ip}:8080/")
  decisive_rc=1
  for attempt in $(seq 1 10); do
    set +e
    kubectl exec -n "${ns}" egress-probe -- python /opt/probe.py "http://${ip}:8080/" >"${decisive_log}" 2>&1
    rc=$?
    set -e
    printf 'attempt %s exit %s\n' "${attempt}" "${rc}" >> "${log}"
    cat "${decisive_log}" >> "${log}"
    if [[ "${want}" == "open" && "${rc}" -eq 0 ]]; then
      decisive_rc=0
      break
    fi
    if [[ "${want}" == "closed" && "${rc}" -eq 2 ]]; then
      decisive_rc=2
      break
    fi
    if [[ "${want}" == "closed" && "${rc}" -eq 0 ]]; then
      decisive_rc=0
    fi
    sleep 2
  done
  transcript_cmd_result "${heading}" "${cmd_s}" "${log}" "${decisive_rc}"
  PROBE_RC="${decisive_rc}"
}

baseline_connections() {
  local ns="$1"
  local ip
  ip=$(cluster_ip "${ns}" fake-endpoint) || fail "geen ClusterIP voor fake-endpoint in ${ns}"
  FAKE_IP="${ip}"
  probe_until "nulmeting zonder policy" "${ns}" "${ip}" open
  if [[ "${PROBE_RC}" -ne 0 ]]; then
    fail "nulmeting zonder policy lukte niet in ${ns}"
  fi
  transcript "Nulmeting zonder policy: verbinding gelukt."
  transcript_blank
  apply_ok "NetworkPolicy deny-egress-probe" \
    kubectl apply -n "${ns}" -f "${ROOT}/manifests/deny-egress-probe.yaml"
  sleep 2
  probe_until "nulmeting met policy" "${ns}" "${ip}" closed
  if [[ "${PROBE_RC}" -eq 2 ]]; then
    BASELINE_BLOCKED=yes
    transcript "Nulmeting met policy: timeout (exit 2). Alleen een timeout telt als geblokkeerd."
  elif [[ "${PROBE_RC}" -eq 0 ]]; then
    BASELINE_BLOCKED=no
    transcript "Nulmeting met policy: verbinding lukte nog. Deze CNI dwingt de policy niet af."
  else
    fail "nulmeting met policy eindigde op exit ${PROBE_RC}. Dat is geen timeout en telt niet als blokkade."
  fi
  transcript_blank
}

prepare_probe_namespace() {
  local ns="$1"
  apply_ok "namespace ${ns}" kubectl create namespace "${ns}"
  apply_ok "label namespace ${ns}" kubectl label namespace "${ns}" \
    pod-security.kubernetes.io/enforce=restricted \
    pod-security.kubernetes.io/enforce-version=latest \
    --overwrite
  apply_configmap "configmap fake-code" "${ns}" fake-code \
    --from-file="fake_endpoint.py=${ROOT}/probe/fake_endpoint.py"
  apply_configmap "configmap probe-code" "${ns}" probe-code \
    --from-file="probe.py=${ROOT}/probe/probe.py"
  apply_ok "fake-endpoint" kubectl apply -n "${ns}" -f "${ROOT}/manifests/fake-endpoint.yaml"
  apply_ok "egress-probe" kubectl apply -n "${ns}" -f "${ROOT}/manifests/probe.yaml"
  wait_ready "${ns}" fake-endpoint
  wait_ready "${ns}" egress-probe
}

record_cni() {
  transcript_exec "kind version" kind version
  [[ "${TRANSCRIPT_RC}" -eq 0 ]] || fail "kind version failed"
  transcript_exec "kubectl version" kubectl version
  [[ "${TRANSCRIPT_RC}" -eq 0 ]] || fail "kubectl version failed"
  transcript_exec "cni images" \
    kubectl -n kube-system get ds,deploy \
    -o jsonpath='{range .items[*]}{.kind}{"/"}{.metadata.name}{" "}{range .spec.template.spec.containers[*]}{.image}{" "}{end}{"\n"}{end}'
  [[ "${TRANSCRIPT_RC}" -eq 0 ]] || fail "cni image listing failed"
}

install_calico() {
  local rendered sumfile
  transcript "kindnet dwingt NetworkPolicy niet af. Calico Open Source ${CALICO_VERSION} wordt geïnstalleerd."
  transcript_blank
  transcript_exec "kind delete cluster" kind delete cluster --name "${KIND_CLUSTER_NAME}"
  [[ "${TRANSCRIPT_RC}" -eq 0 ]] || fail "kind delete failed"
  rendered=$(mktemp)
  bash "${ROOT}/scripts/render-kind-config.sh" "${rendered}" calico
  transcript_exec "kind create cluster with calico cni disabled default" \
    kind create cluster \
    --name "${KIND_CLUSTER_NAME}" \
    --image "${KIND_NODE_IMAGE}" \
    --config "${rendered}" \
    --wait 180s
  [[ "${TRANSCRIPT_RC}" -eq 0 ]] || fail "kind create with Calico config failed"
  require_kind_context
  bash "${ROOT}/scripts/load-images.sh"
  sumfile=$(mktemp)
  curl -fsSL -o "${sumfile}" \
    "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"
  echo "${CALICO_SHA256}  ${sumfile}" | sha256sum -c -
  apply_ok "calico manifest" kubectl apply -f "${sumfile}"
  transcript_exec "calico-node rollout" \
    kubectl -n kube-system rollout status ds/calico-node --timeout=300s
  [[ "${TRANSCRIPT_RC}" -eq 0 ]] || fail "calico-node did not become ready"
  transcript_exec "calico-kube-controllers rollout" \
    kubectl -n kube-system rollout status deploy/calico-kube-controllers --timeout=300s
  [[ "${TRANSCRIPT_RC}" -eq 0 ]] || fail "calico-kube-controllers did not become ready"
  transcript_exec "nodes ready" kubectl wait --for=condition=Ready nodes --all --timeout=300s
  [[ "${TRANSCRIPT_RC}" -eq 0 ]] || fail "node not ready after Calico"
  assert_audit
  record_cni
}

ensure_enforcement() {
  transcript "## NetworkPolicy"
  transcript_blank
  transcript "Eerst een meting of de CNI van dit cluster NetworkPolicy afdwingt. Er wordt niets aangenomen over kindnet."
  transcript_blank
  record_cni
  prepare_probe_namespace netpol-check
  baseline_connections netpol-check
  if [[ "${BASELINE_BLOCKED}" == yes ]]; then
    transcript "Conclusie: de CNI die nu draait dwingt NetworkPolicy af. Calico is niet geïnstalleerd."
    transcript_blank
    kubectl delete namespace netpol-check --wait=false >/dev/null 2>&1 || true
    return 0
  fi
  install_calico
  prepare_probe_namespace netpol-check
  baseline_connections netpol-check
  if [[ "${BASELINE_BLOCKED}" != yes ]]; then
    fail "NetworkPolicy wordt ook na Calico niet afgedwongen"
  fi
  transcript "Conclusie: kindnet dwingde NetworkPolicy niet af. Na Calico Open Source ${CALICO_VERSION} wel."
  transcript_blank
  kubectl delete namespace netpol-check --wait=false >/dev/null 2>&1 || true
}

discover_api() {
  API_IP=$(kubectl get svc kubernetes -n default -o jsonpath='{.spec.clusterIP}')
  API_PORT=$(kubectl get svc kubernetes -n default -o jsonpath='{.spec.ports[0].port}')
  EP_IP=$(kubectl get endpoints kubernetes -n default -o jsonpath='{.subsets[0].addresses[0].ip}')
  EP_PORT=$(kubectl get endpoints kubernetes -n default -o jsonpath='{.subsets[0].ports[0].port}')
  [[ "${API_IP}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "api service IP is not IPv4: ${API_IP}"
  [[ "${EP_IP}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "api endpoint IP is not IPv4: ${EP_IP}"
  [[ "${API_PORT}" =~ ^[0-9]+$ ]] || fail "api service port is not numeric: ${API_PORT}"
  [[ "${EP_PORT}" =~ ^[0-9]+$ ]] || fail "api endpoint port is not numeric: ${EP_PORT}"
  transcript "API-server service ${API_IP}:${API_PORT}, endpoint ${EP_IP}:${EP_PORT}."
  transcript "De agent-policy laat alleen die adressen toe. DNS naar kube-dns zit er niet bij."
  transcript_blank
}

apply_agent_egress() {
  local ns="$1"
  local rendered
  rendered=$(mktemp)
  cat > "${rendered}" <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: agent-egress-api-only
  namespace: ${ns}
spec:
  podSelector:
    matchLabels:
      app: sre-agent
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: ${API_IP}/32
      ports:
        - protocol: TCP
          port: ${API_PORT}
    - to:
        - ipBlock:
            cidr: ${EP_IP}/32
      ports:
        - protocol: TCP
          port: ${EP_PORT}
EOF
  apply_ok "NetworkPolicy agent-egress-api-only" kubectl apply -f "${rendered}"
}

apply_agent_job() {
  local ns="$1"
  local name="$2"
  local execution="$3"
  local strip="$4"
  local expect_marker="$5"
  local expect_egress="$6"
  local fake_url="$7"
  local approved="$8"
  local rendered
  rendered=$(mktemp)
  sed \
    -e "s|__NS__|${ns}|g" \
    -e "s|__NAME__|${name}|g" \
    -e "s|__EXECUTION__|${execution}|g" \
    -e "s|__STRIP__|${strip}|g" \
    -e "s|__EXPECT_MARKER__|${expect_marker}|g" \
    -e "s|__EXPECT_EGRESS__|${expect_egress}|g" \
    -e "s|__FAKE_URL__|${fake_url}|g" \
    -e "s|__APPROVED__|${approved}|g" \
    "${ROOT}/manifests/agent-job.yaml.tmpl" > "${rendered}"
  apply_ok "job ${name}" kubectl apply -f "${rendered}"
}

wait_job_logs() {
  local ns="$1"
  local name="$2"
  local log wait_log rc cmd_s complete failed attempt
  wait_log=$(mktemp)
  cmd_s="poll job/${name} until Complete or Failed"
  : > "${wait_log}"
  rc=1
  complete=""
  failed=""
  for attempt in $(seq 1 90); do
    complete=$(kubectl get job -n "${ns}" "${name}" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>>"${wait_log}" || true)
    failed=$(kubectl get job -n "${ns}" "${name}" -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>>"${wait_log}" || true)
    printf 'attempt %s complete=%s failed=%s\n' "${attempt}" "${complete}" "${failed}" >> "${wait_log}"
    if [[ "${complete}" == True ]]; then
      rc=0
      break
    fi
    if [[ "${failed}" == True ]]; then
      rc=1
      break
    fi
    sleep 2
  done
  transcript_cmd_result "wacht op job ${name}" "${cmd_s}" "${wait_log}" "${rc}"
  log=$(mktemp)
  transcript_exec "pod-log job ${name}" kubectl logs -n "${ns}" "job/${name}"
  cp "${TRANSCRIPT_LOG}" "${log}"
  AGENT_LOG="${log}"
  if [[ "${rc}" -ne 0 ]]; then
    fail "job ${ns}/${name} did not complete"
  fi
}

tool_section() {
  local log="$1"
  local extracted cmd_s rc
  extracted=$(mktemp)
  cmd_s="grep ^TOOL_LOG"
  set +e
  grep '^TOOL_LOG ' "${log}" > "${extracted}"
  rc=$?
  set -e
  if [[ "${rc}" -eq 1 ]]; then
    printf 'no TOOL_LOG lines\n' > "${extracted}"
  elif [[ "${rc}" -ne 0 ]]; then
    fail "grep TOOL_LOG failed"
  else
    rc=0
  fi
  transcript_block "Tool-log (apart van de API-audit)" "${cmd_s}" "${extracted}"
  transcript "Exit ${rc}."
  transcript_blank
  transcript "De API-audit ziet dit niet. Die legt alleen API-verzoeken vast. Daarom staat de tool-aanroep hier apart."
  transcript_blank
}

read_audit() {
  local ns="$1"
  local raw extract attempt rc
  raw=$(mktemp)
  extract=$(mktemp)
  rc=1
  for attempt in $(seq 1 5); do
    set +e
    docker exec "${NODE}" cat /var/log/kubernetes/kube-apiserver-audit.log > "${raw}" 2>"${extract}"
    rc=$?
    set -e
    if [[ "${rc}" -eq 0 && -s "${raw}" ]]; then
      break
    fi
    sleep 2
  done
  if [[ "${rc}" -ne 0 ]]; then
    transcript_block "audit log lezen" "docker exec ${NODE} cat /var/log/kubernetes/kube-apiserver-audit.log" "${extract}"
    transcript "Exit ${rc}."
    transcript_blank
    fail "audit log not readable"
  fi
  python3 "${ROOT}/scripts/audit-extract.py" "${ns}" < "${raw}" > "${extract}"
  transcript_block "auditregels ${ns}" \
    "docker exec ${NODE} cat /var/log/kubernetes/kube-apiserver-audit.log | python3 scripts/audit-extract.py ${ns}" \
    "${extract}"
  transcript "Exit 0."
  transcript_blank
  AUDIT_EXTRACT="${extract}"
}

assert_audit_lines() {
  local file="$1"
  local kind="$2"
  if ! grep -F 'resource=pods' "${file}" | grep -F 'subresource=log' | grep -q -F 'code=200'; then
    fail "${kind}: audit log has no allowed pods/log read"
  fi
  if [[ "${kind}" == unsafe ]]; then
    if ! grep -F 'resource=secrets' "${file}" | grep -q -F 'code=200'; then
      fail "unsafe: audit log has no allowed secrets get"
    fi
  else
    if ! grep -F 'resource=secrets' "${file}" | grep -q -F 'code=403'; then
      fail "hardened: audit log has no Forbidden secrets get"
    fi
    if ! grep -i -q 'forbidden' "${file}"; then
      fail "hardened: audit extract does not contain Forbidden"
    fi
  fi
}

run_can_i() {
  local ns="$1"
  local expect_secrets="$2"
  local sa="system:serviceaccount:${ns}:sre-agent"
  local get_s list_s watch_s log_s
  get_s=$(capture_can_i "can-i get secrets" get secrets -n "${ns}" --as="${sa}")
  list_s=$(capture_can_i "can-i list secrets" list secrets -n "${ns}" --as="${sa}")
  watch_s=$(capture_can_i "can-i watch secrets" watch secrets -n "${ns}" --as="${sa}")
  log_s=$(capture_can_i "can-i get pods/log" get pods/log -n "${ns}" --as="${sa}")
  [[ "${get_s}" == "${expect_secrets}" ]] || fail "get secrets is ${get_s}, expected ${expect_secrets}"
  [[ "${list_s}" == "${expect_secrets}" ]] || fail "list secrets is ${list_s}, expected ${expect_secrets}"
  [[ "${watch_s}" == "${expect_secrets}" ]] || fail "watch secrets is ${watch_s}, expected ${expect_secrets}"
  [[ "${log_s}" == yes ]] || fail "get pods/log is ${log_s}, expected yes"
  transcript "can-i get/list/watch secrets=${expect_secrets}, get pods/log=yes."
  transcript_blank
}

prepare_variant_workloads() {
  local ns="$1"
  apply_configmap "configmap web-content" "${ns}" web-content \
    --from-file="nginx.conf=${ROOT}/app/nginx.conf" \
    --from-file="login.html=${ROOT}/app/login.html" \
    --from-file="app.py=${ROOT}/app/app.py"
  apply_configmap "configmap client-code" "${ns}" client-code \
    --from-file="client.py=${ROOT}/client/client.py" \
    --from-file="marker.txt=${ROOT}/marker.txt"
  apply_configmap "configmap fake-code" "${ns}" fake-code \
    --from-file="fake_endpoint.py=${ROOT}/probe/fake_endpoint.py"
  apply_configmap "configmap probe-code" "${ns}" probe-code \
    --from-file="probe.py=${ROOT}/probe/probe.py"
  apply_configmap "configmap agent-code" "${ns}" agent-code \
    --from-file="agent.py=${ROOT}/agent/agent.py"
  apply_ok "web" kubectl apply -n "${ns}" -f "${ROOT}/manifests/web.yaml"
  apply_ok "fake-endpoint" kubectl apply -n "${ns}" -f "${ROOT}/manifests/fake-endpoint.yaml"
  apply_ok "egress-probe" kubectl apply -n "${ns}" -f "${ROOT}/manifests/probe.yaml"
  wait_ready "${ns}" web
  wait_ready "${ns}" fake-endpoint
  wait_ready "${ns}" egress-probe
  apply_ok "client job" kubectl apply -n "${ns}" -f "${ROOT}/manifests/client-job.yaml"
  if ! kubectl wait -n "${ns}" --for=condition=complete job/client --timeout=180s; then
    kubectl logs -n "${ns}" job/client >&2 || true
    kubectl logs -n "${ns}" web --all-containers >&2 || true
    fail "client job failed in ${ns}"
  fi
  transcript_exec "client log" kubectl logs -n "${ns}" job/client
  [[ "${TRANSCRIPT_RC}" -eq 0 ]] || fail "client log failed"
  assert_file_contains "${TRANSCRIPT_LOG}" "REQUEST field=user-agent" "client did not send the user-agent request"
  assert_file_contains "${TRANSCRIPT_LOG}" "status=200" "client request was not HTTP 200"
  # nginx can buffer a line for a moment. Retry before the transcripted check.
  local_nginx="/tmp/logs-pi-nginx-${ns}.log"
  local_app="/tmp/logs-pi-app-${ns}.log"
  fields_try=$(mktemp)
  fields_rc=1
  for _attempt in $(seq 1 8); do
    kubectl logs -n "${ns}" web -c nginx > "${local_nginx}" 2>>"${fields_try}" || true
    kubectl logs -n "${ns}" web -c app > "${local_app}" 2>>"${fields_try}" || true
    set +e
    python3 "${ROOT}/scripts/check-fields.py" "${ROOT}/marker.txt" "${local_nginx}" "${local_app}" >"${fields_try}" 2>&1
    fields_rc=$?
    set -e
    if [[ "${fields_rc}" -eq 0 ]]; then
      break
    fi
    sleep 2
  done
  transcript_exec "nginx log" kubectl logs -n "${ns}" web -c nginx
  [[ "${TRANSCRIPT_RC}" -eq 0 ]] || fail "nginx log failed"
  cp "${TRANSCRIPT_LOG}" "${local_nginx}"
  transcript_exec "app log" kubectl logs -n "${ns}" web -c app
  [[ "${TRANSCRIPT_RC}" -eq 0 ]] || fail "app log failed"
  cp "${TRANSCRIPT_LOG}" "${local_app}"
  transcript_exec "velden in de logs" \
    python3 "${ROOT}/scripts/check-fields.py" \
    "${ROOT}/marker.txt" \
    "${local_nginx}" \
    "${local_app}"
  [[ "${TRANSCRIPT_RC}" -eq 0 ]] || fail "marker missing from one of the four fields in ${ns}"
  assert_file_contains "${TRANSCRIPT_LOG}" "FIELD user-agent present" "user-agent field missing"
  assert_file_contains "${TRANSCRIPT_LOG}" "FIELD query present" "query field missing"
  assert_file_contains "${TRANSCRIPT_LOG}" "FIELD referer present" "referer field missing"
  assert_file_contains "${TRANSCRIPT_LOG}" "FIELD username present" "username field missing"
}

finish_egress_state() {
  local ns="$1"
  local variant="$2"
  if [[ "${BASELINE_BLOCKED}" != yes ]]; then
    fail "${variant}: NetworkPolicy blokkeerde de nulmeting niet"
  fi
  if [[ "${variant}" == unsafe ]]; then
    apply_ok "verwijder deny-egress-probe" \
      kubectl delete -n "${ns}" -f "${ROOT}/manifests/deny-egress-probe.yaml"
    sleep 2
    probe_until "verbinding na verwijderen policy" "${ns}" "${FAKE_IP}" open
    if [[ "${PROBE_RC}" -ne 0 ]]; then
      fail "unsafe: verbinding bleef dicht nadat de policy weg was"
    fi
    transcript "Onveilig eindigt zonder egress-policy. De verbinding lukt weer."
    transcript_blank
  else
    transcript "Gehard laat de deny-policy op de probe staan."
    transcript_blank
    apply_agent_egress "${ns}"
  fi
}

assert_agent() {
  local log="$1"
  local kind="$2"
  if [[ "${kind}" == unsafe ]]; then
    assert_file_contains "${log}" "STUB input=raw marker=present tool=get_secrets" "unsafe stub did not see the marker"
    assert_file_contains "${log}" "executed=true" "unsafe tool was not executed"
    assert_file_contains "${log}" "SECRET_VALUE name=demo-dummy key=token value=${DUMMY_VALUE}" "unsafe did not read the dummy value"
    assert_file_contains "${log}" "MEASURE verb=get resource=secrets name=demo-dummy http=200" "unsafe measure was not allowed"
    assert_file_contains "${log}" "EGRESS" "unsafe missing egress line"
    assert_file_contains "${log}" "result=connected" "unsafe egress did not connect"
  elif [[ "${kind}" == stripped ]]; then
    assert_closed_agent "${log}" "stripped"
    assert_file_contains "${log}" "STUB input=stripped marker=absent tool=none" "stripped stub still saw the marker"
    assert_file_contains "${log}" "TOOL_LOG tool=none" "stripped stub proposed a tool"
    assert_file_contains "${log}" "STRIPPED " "stripped view was not printed"
  elif [[ "${kind}" == approved ]]; then
    assert_closed_agent "${log}" "approved"
    assert_file_contains "${log}" "STUB input=raw marker=present tool=get_secrets" "approved stub missed the marker"
    assert_file_contains "${log}" "TOOL_LOG tool=get_secrets proposal=true approved=true executed=true http=403" "approved tool was not a 403 from the stub"
  else
    assert_closed_agent "${log}" "worst-case"
    assert_file_contains "${log}" "STUB input=raw marker=present tool=get_secrets" "worst-case stub missed the marker"
    assert_file_contains "${log}" "TOOL_LOG tool=get_secrets proposal=true approved=false executed=false" "worst-case tool was not a refused proposal"
  fi
}

wait_policy_gate() {
  local ns="$1"
  local ip="$2"
  local log attempt_log attempt rc connected blocked_at line
  apply_ok "policy-gate" kubectl apply -n "${ns}" -f "${ROOT}/manifests/policy-gate.yaml"
  wait_ready "${ns}" policy-gate
  log=$(mktemp)
  attempt_log=$(mktemp)
  connected=0
  blocked_at=0
  for attempt in $(seq 1 30); do
    set +e
    kubectl exec -n "${ns}" policy-gate -- python /opt/probe.py "http://${ip}:8080/" >"${attempt_log}" 2>&1
    rc=$?
    set -e
    line=$(tr '\n' ' ' < "${attempt_log}")
    printf 'EGRESS_GATE attempt=%s exit=%s %s\n' "${attempt}" "${rc}" "${line}" >> "${log}"
    if [[ "${rc}" -eq 0 ]]; then
      connected=$((connected + 1))
    elif [[ "${rc}" -eq 2 ]]; then
      blocked_at="${attempt}"
      break
    fi
    sleep 1
  done
  transcript_block "testpod policy-gate" \
    "kubectl exec policy-gate -- python /opt/probe.py http://${ip}:8080/" \
    "${log}"
  transcript "policy-gate verbonden=${connected} eerste_timeout=${blocked_at}."
  transcript_blank
  if [[ "${blocked_at}" -eq 0 ]]; then
    fail "policy-gate zag geen timeout. De policy is niet aantoonbaar actief."
  fi
  transcript "Bevinding: tussen het aanmaken van NetworkPolicy agent-egress-api-only en de afdwinging door de CNI zit een open venster. Een pod met label app=sre-agent die in dat venster start kan het nep-endpoint nog bereiken. Testpod policy-gate logde elke poging. Verbonden pogingen: ${connected}. Eerste timeout: poging ${blocked_at}. De agent-job start pas na die timeout. Een nieuwe pod heeft daarna nog een eigen venster; die pogingen staan als EGRESS_GATE in de agentlog. De meting is de EGRESS-poging daarna. Verbindt die, dan faalt de job. Alleen een timeout telt als geblokkeerd."
  transcript_blank
  kubectl delete pod -n "${ns}" policy-gate --wait=false >/dev/null 2>&1 || true
}

confirm_endpoint_up() {
  local ns="$1"
  local ip="$2"
  local heading="$3"
  local log rc
  log=$(mktemp)
  set +e
  kubectl exec -n "${ns}" endpoint-alive -- python /opt/probe.py "http://${ip}:8080/" >"${log}" 2>&1
  rc=$?
  set -e
  transcript_cmd_result "${heading}" \
    "kubectl exec -n ${ns} endpoint-alive -- python /opt/probe.py http://${ip}:8080/" \
    "${log}" "${rc}"
  if [[ "${rc}" -ne 0 ]]; then
    fail "positieve controle mislukt (exit ${rc}). Het nep-endpoint antwoordt niet vanuit een pod zonder egress-policy, dus een timeout van de agent telt niet als policy-blokkade."
  fi
}

count_audit() {
  local file="$1"
  local code="$2"
  local agent="$3"
  local n
  n=$(grep -F 'resource=secrets' "${file}" | grep -F "code=${code}" | grep -c -F "userAgent=${agent}" || true)
  printf '%s' "${n:-0}"
}

explain_audit() {
  local file="$1"
  local kind="$2"
  local agent_200 measure_200 agent_403 measure_403
  agent_200=$(count_audit "${file}" 200 demo-agent)
  measure_200=$(count_audit "${file}" 200 demo-measure)
  agent_403=$(count_audit "${file}" 403 demo-agent)
  measure_403=$(count_audit "${file}" 403 demo-measure)
  transcript "Audit-uitleg: userAgent=demo-measure is de aparte meet-GET (MEASURE), niet de stub. userAgent=demo-agent op secrets is de tool-aanroep get_secrets van de stub."
  if [[ "${kind}" == unsafe ]]; then
    transcript "Onveilig: ${agent_200}× secrets code=200 userAgent=demo-agent (tool van de stub) en ${measure_200}× secrets code=200 userAgent=demo-measure (meet-GET)."
    [[ "${agent_200}" -eq 1 && "${measure_200}" -eq 1 ]] || fail "unsafe audit telt niet 1× demo-agent 200 en 1× demo-measure 200"
  else
    transcript "Gehard: ${measure_403}× secrets code=403 userAgent=demo-measure (meet-GET). ${agent_403}× secrets code=403 userAgent=demo-agent (stub met APPROVED=true). demo-agent 200: ${agent_200}."
    [[ "${agent_403}" -ge 1 && "${measure_403}" -ge 1 && "${agent_200}" -eq 0 ]] || fail "hardened audit mist de 403 van de stub of van de meet-GET"
  fi
  transcript_blank
}

assert_closed_agent() {
  local log="$1"
  local label="$2"
  assert_file_excludes "${log}" "${DUMMY_VALUE}" "${label} run printed the dummy value"
  assert_file_contains "${log}" "MEASURE verb=get resource=secrets name=demo-dummy http=403" "${label} measure was not Forbidden"
  assert_file_contains "${log}" "EGRESS_GATE " "${label} did not log the per-pod window"
  assert_file_contains "${log}" "EGRESS url=" "${label} missing the measurement attempt"
  assert_file_contains "${log}" "result=blocked error=timeout" "${label} egress was not a timeout"
  assert_file_contains "${log}" "EGRESS_POSITIVE destination=api result=connected" "${label} allowed destination did not answer"
  assert_file_contains "${log}" "DNS name=kube-dns.kube-system.svc.cluster.local result=blocked error=timeout" "${label} DNS lookup was not a timeout"
  if grep -F 'EGRESS url=' "${log}" | grep -q -F 'result=connected'; then
    fail "${label}: an agent egress attempt connected after the policy gate"
  fi
}

run_variant() {
  local variant="$1"
  local ns="variant-${variant}"
  local fake_url
  summary_switch "variant-${variant}"
  if [[ "${variant}" == unsafe ]]; then
    transcript "## Variant onveilig"
  else
    transcript "## Variant gehard"
  fi
  transcript_blank
  prepare_variant_workloads "${ns}"
  transcript "### Maatregel: egress, nulmeting"
  transcript_blank
  baseline_connections "${ns}"
  finish_egress_state "${ns}" "${variant}"
  fake_url="http://${FAKE_IP}:8080/"
  transcript "### Maatregel: RBAC"
  transcript_blank
  if [[ "${variant}" == unsafe ]]; then
    run_can_i "${ns}" yes
    transcript "### Maatregel: stub, directe uitvoering"
    transcript_blank
    apply_agent_job "${ns}" sre-agent direct false present open "${fake_url}" false
    wait_job_logs "${ns}" sre-agent
    assert_agent "${AGENT_LOG}" unsafe
    tool_section "${AGENT_LOG}"
  else
    run_can_i "${ns}" no
    transcript "### Maatregel: egress-venster"
    transcript_blank
    transcript "De agent start pas nadat een testpod met label app=sre-agent een timeout naar het nep-endpoint heeft gemeten."
    transcript_blank
    wait_policy_gate "${ns}" "${FAKE_IP}"
    apply_ok "endpoint-alive" kubectl apply -n "${ns}" -f "${ROOT}/manifests/endpoint-alive.yaml"
    wait_ready "${ns}" endpoint-alive
    confirm_endpoint_up "${ns}" "${FAKE_IP}" "positieve controle voor de agent"
    transcript "### Maatregel: bezoekersvelden"
    transcript_blank
    transcript "De stub krijgt eerst de gestripte tekst. De ruwe regels staan als RAW in dezelfde uitvoer, zodat zichtbaar is wat er weg is."
    transcript_blank
    apply_agent_job "${ns}" sre-agent propose true absent closed "${fake_url}" false
    wait_job_logs "${ns}" sre-agent
    assert_agent "${AGENT_LOG}" stripped
    tool_section "${AGENT_LOG}"
    confirm_endpoint_up "${ns}" "${FAKE_IP}" "positieve controle na sre-agent"
    transcript "### Maatregel: goedkeuring geweigerd"
    transcript_blank
    transcript "Zelfde stub, nu op de ongestripte tekst. De tool blijft een voorstel. APPROVED staat op false en CI keurt niet goed."
    transcript_blank
    apply_agent_job "${ns}" sre-agent-worst-case propose false present closed "${fake_url}" false
    wait_job_logs "${ns}" sre-agent-worst-case
    assert_agent "${AGENT_LOG}" worst
    tool_section "${AGENT_LOG}"
    confirm_endpoint_up "${ns}" "${FAKE_IP}" "positieve controle na sre-agent-worst-case"
    transcript "### Maatregel: goedkeuring die de tool uitvoert"
    transcript_blank
    transcript "APPROVED=true. De stub roept get_secrets zelf aan. Verwacht is HTTP 403, geen secretwaarde, en in de audit User-Agent demo-agent."
    transcript_blank
    apply_agent_job "${ns}" sre-agent-approved propose false present closed "${fake_url}" true
    wait_job_logs "${ns}" sre-agent-approved
    assert_agent "${AGENT_LOG}" approved
    tool_section "${AGENT_LOG}"
    confirm_endpoint_up "${ns}" "${FAKE_IP}" "positieve controle na sre-agent-approved"
    kubectl delete pod -n "${ns}" endpoint-alive --wait=false >/dev/null 2>&1 || true
  fi
  transcript "### Maatregel: API-server-audit"
  transcript_blank
  read_audit "${ns}"
  assert_audit_lines "${AUDIT_EXTRACT}" "${variant}"
  explain_audit "${AUDIT_EXTRACT}" "${variant}"
  transcript "Variant ${variant}: controles gehaald."
  transcript_blank
}

bash "${ROOT}/scripts/load-images.sh"
summary_open audit-setup
transcript "## API-server-audit"
transcript_blank
transcript "Aangezet via --audit-policy-file in de kind-config. Zonder die vlag logt de API-server geen events."
transcript_blank
assert_audit
summary_switch networkpolicy
ensure_enforcement
summary_switch cluster-setup
transcript "## Clusterobjecten"
transcript_blank
discover_api
apply_ok "namespaces" kubectl apply -f "${ROOT}/manifests/namespaces.yaml"
apply_ok "rbac onveilig" kubectl apply -f "${ROOT}/manifests/rbac-unsafe.yaml"
apply_ok "rbac gehard" kubectl apply -f "${ROOT}/manifests/rbac-hardened.yaml"
apply_ok "dummy secrets" kubectl apply -f "${ROOT}/manifests/secret-dummy.yaml"
run_variant unsafe
run_variant hardened
transcript "Demo klaar."
transcript_blank
