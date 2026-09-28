#!/usr/bin/env bash
# Shared helpers for the unix-lessons-containers demos.
# These demos only record privilege differences. They do not escape a container,
# mount a runtime socket, or write to the host.

if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "lib.sh must be sourced from bash" >&2
  exit 1
fi

export BUSYBOX_DIGEST="sha256:bdf57e528e45e4433820e045b29b4597825a1c9e38353532d90a01445013f82e"
export BUSYBOX_IMAGE="docker.io/library/busybox@${BUSYBOX_DIGEST}"
export BUSYBOX_TAG="docker.io/library/busybox:1.37.0"
export DEBIAN_IMAGE="debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251"
export KIND_NODE_IMAGE="kindest/node:v1.34.11@sha256:44e222ee2132dab25ff87301682f89eb82c7880ea3a1bf543bfe9708fd08d67d"


# kind names the kubeconfig context kind-<cluster_name>.
# The workflow sets cluster_name to unix-lessons, so the context is kind-unix-lessons.
require_kind_context() {
  local expected="kind-unix-lessons"
  local current err detail
  err=$(mktemp)
  if ! current=$(kubectl config current-context 2>"${err}"); then
    detail=$(tr '\n' ' ' < "${err}" || true)
    fail "refusing to continue: kubectl config current-context failed (${detail}). Expected context ${expected}, the throw-away kind cluster."
  fi
  # Command substitution already drops the trailing newline. Context names have no spaces.
  if [[ "${current}" != "${expected}" ]]; then
    fail "refusing to continue: kubectl context is '${current}', expected '${expected}' (kind cluster unix-lessons). These demos use that cluster's admin kubeconfig and must not run against any other context."
  fi
}

summary() {
  printf '%s\n' "$1"
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf '%s\n' "$1" >> "${GITHUB_STEP_SUMMARY}"
  fi
}

summary_blank() {
  summary ""
}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  summary "FAIL: $*"
  if [[ -n "${SUMMARY_PATH:-}" ]]; then
    printf '\nFAIL: %s\n' "$*" >> "${SUMMARY_PATH}" || true
  fi
  exit 1
}

# Short pair transcript. Demos append to summaries/<slug>.md while they run.
# The workflow copies that file into $GITHUB_STEP_SUMMARY afterwards, so a
# failure in that copy or in the artifact upload does not change the demo result.
SUMMARY_PATH=""

summary_open() {
  local slug="$1"
  local root="${ROOT:-.}"
  mkdir -p "${root}/summaries"
  SUMMARY_PATH="${root}/summaries/${slug}.md"
  : > "${SUMMARY_PATH}"
  trap 'summary_on_exit' EXIT
}

summary_on_exit() {
  local rc=$?
  if [[ "${SUMMARY_EXIT_DONE:-}" == yes ]]; then
    exit "$rc"
  fi
  SUMMARY_EXIT_DONE=yes
  if [[ "$rc" -ne 0 && -n "${SUMMARY_PATH}" && -f "${SUMMARY_PATH}" ]]; then
    if ! grep -q '^FAIL:' "${SUMMARY_PATH}"; then
      printf '\nFAIL: exit %s\n' "$rc" >> "${SUMMARY_PATH}" || true
    fi
  fi
  exit "$rc"
}

transcript() {
  if [[ -z "${SUMMARY_PATH}" ]]; then
    return 0
  fi
  printf '%s\n' "$1" >> "${SUMMARY_PATH}" || true
}

transcript_blank() {
  transcript ""
}

# Shell-quoted command line, one argument per argv element that was executed.
format_cmd() {
  local out="" arg
  for arg in "$@"; do
    printf -v out '%s %q' "$out" "$arg"
  done
  printf '%s\n' "${out# }"
}

# transcript_block HEADING COMMAND FILE
# COMMAND is the command that ran. FILE is its captured combined output.
transcript_block() {
  local heading="$1"
  local command="$2"
  local file="$3"
  local fence='```'
  transcript "### ${heading}"
  transcript_blank
  transcript "Command:"
  transcript_blank
  transcript '```'
  transcript "${command}"
  transcript '```'
  transcript_blank
  transcript "Output:"
  transcript_blank
  if [[ -f "$file" ]] && grep -q '```' "$file"; then
    fence='````'
  fi
  transcript "${fence}"
  if [[ -f "$file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      transcript "$line"
    done < "$file"
  fi
  transcript "${fence}"
  transcript_blank
}

# transcript_cmd_result HEADING COMMAND FILE EXIT
# COMMAND already ran. FILE is its captured combined output. EXIT is that status.
transcript_cmd_result() {
  local heading="$1"
  local command="$2"
  local file="$3"
  local rc="$4"
  transcript_block "${heading}" "${command}" "${file}"
  transcript "Exit ${rc}."
  transcript_blank
}

# transcript_exec HEADING COMMAND...
# Runs COMMAND, then records the command, combined output, and exit code.
# A non-zero status is recorded. It does not fail the demo.
transcript_exec() {
  local heading="$1"
  shift
  local log rc cmd_s
  cmd_s=$(format_cmd "$@")
  log=$(mktemp)
  set +e
  "$@" >"${log}" 2>&1
  rc=$?
  set -e
  transcript_cmd_result "${heading}" "${cmd_s}" "${log}" "${rc}"
}

# capture_can_i HEADING ARGS...
# Same yes/no result as can_i. Also records the command, output, and exit code.
capture_can_i() {
  local heading="$1"
  shift
  local log rc cmd_s out
  cmd_s=$(format_cmd kubectl auth can-i "$@")
  log=$(mktemp)
  set +e
  kubectl auth can-i "$@" >"${log}" 2>&1
  rc=$?
  set -e
  transcript_cmd_result "${heading}" "${cmd_s}" "${log}" "${rc}"
  out=$(tr -d '[:space:]' < "${log}")
  if [[ "$out" != "yes" && "$out" != "no" ]]; then
    fail "unexpected 'kubectl auth can-i $*' output (exit ${rc}): ${out}"
  fi
  printf '%s' "$out"
}

summary_file() {
  local file="$1"
  [[ -f "$file" ]] || fail "missing summary file: $file"
  cat "$file"
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    cat "$file" >> "${GITHUB_STEP_SUMMARY}"
  fi
}

# kubectl auth can-i exits 1 when the answer is "no".
can_i() {
  local out rc
  set +e
  out=$(kubectl auth can-i "$@" 2>&1)
  rc=$?
  set -e
  out=$(printf '%s' "$out" | tr -d '[:space:]')
  if [[ "$out" != "yes" && "$out" != "no" ]]; then
    fail "unexpected 'kubectl auth can-i $*' output (exit ${rc}): ${out}"
  fi
  printf '%s' "$out"
}

# expect_denied PATTERN DESCRIPTION COMMAND...
# PATTERN is an extended regex that must appear in the combined output.
# Combined output is teed to a file. LAST_CMD is the command that ran.
expect_denied() {
  local pattern="$1"
  local desc="$2"
  shift 2
  local log rc cmd_s
  cmd_s=$(format_cmd "$@")
  LAST_CMD="${cmd_s}"
  log=$(mktemp)
  set +e
  "$@" 2>&1 | tee "${log}" >/dev/null
  rc=${PIPESTATUS[0]}
  set -e
  if [[ "$rc" -eq 0 ]]; then
    cat "$log" >&2
    transcript_block "${desc}" "${cmd_s}" "${log}"
    fail "${desc} was accepted"
  fi
  if [[ -n "$pattern" ]] && ! grep -E -q "$pattern" "$log"; then
    cat "$log" >&2
    transcript_block "${desc}" "${cmd_s}" "${log}"
    fail "${desc} was denied, but output did not match /${pattern}/"
  fi
  summary "Denied: ${desc} (exit ${rc})"
  summary '```'
  sed -n '1,30p' "$log" | while IFS= read -r line; do
    summary "$line"
  done
  summary '```'
  summary_blank
  export DENIED_LOG="$log"
  export LAST_CMD
  export DENIED_RC="$rc"
}

# api_patch_as USER NAMESPACE NAME BODY_FILE
# PATCH a ConfigMap as USER through kubectl proxy. The proxy holds the admin
# credentials; Impersonate-User asks the API to authorize cm-editor. No GET.
api_patch_as() {
  local as_user="$1"
  local namespace="$2"
  local name="$3"
  local body_file="$4"
  local port pid out http_code ready _
  port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
  kubectl proxy --port="${port}" --address=127.0.0.1 >/tmp/unix-lessons-proxy.log 2>&1 &
  pid=$!
  ready=no
  for _ in $(seq 1 50); do
    if curl -sf -o /dev/null "http://127.0.0.1:${port}/version"; then
      ready=yes
      break
    fi
    sleep 0.2
  done
  if [[ "$ready" != yes ]]; then
    cat /tmp/unix-lessons-proxy.log >&2 || true
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    return 1
  fi
  out=$(mktemp)
  # curl's non-zero status must not abort the caller: expect_denied treats
  # that status as the admission/API result. A set -e inside this function
  # would exit the shell on `return 1` before the caller can record it.
  # Written to files because callers invoke this function in a pipeline,
  # which would drop variables set in that subshell. The files are the
  # command that ran and the HTTP status curl reported.
  mkdir -p /tmp/unix-lessons
  format_cmd curl -sS -o "${out}" -w '%{http_code}' \
    -X PATCH \
    -H "Content-Type: application/merge-patch+json" \
    -H "Impersonate-User: ${as_user}" \
    --data-binary @"${body_file}" \
    "http://127.0.0.1:${port}/api/v1/namespaces/${namespace}/configmaps/${name}" \
    > /tmp/unix-lessons/api-patch.cmd
  http_code=$(curl -sS -o "${out}" -w '%{http_code}' \
    -X PATCH \
    -H "Content-Type: application/merge-patch+json" \
    -H "Impersonate-User: ${as_user}" \
    --data-binary @"${body_file}" \
    "http://127.0.0.1:${port}/api/v1/namespaces/${namespace}/configmaps/${name}" || true)
  printf '%s\n' "${http_code}" > /tmp/unix-lessons/api-patch.http
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  cat "${out}"
  case "${http_code}" in
    2*) return 0 ;;
    *) return 1 ;;
  esac
}

# expect_ok DESCRIPTION COMMAND...
# Combined output is teed to a file. LAST_CMD is the command that ran.
expect_ok() {
  local desc="$1"
  shift
  local log rc cmd_s
  cmd_s=$(format_cmd "$@")
  LAST_CMD="${cmd_s}"
  log=$(mktemp)
  set +e
  "$@" 2>&1 | tee "${log}" >/dev/null
  rc=${PIPESTATUS[0]}
  set -e
  if [[ "$rc" -ne 0 ]]; then
    cat "$log" >&2
    transcript_block "${desc}" "${cmd_s}" "${log}"
    fail "${desc} failed (exit ${rc})"
  fi
  summary "Allowed: ${desc}"
  summary_blank
  export OK_LOG="$log"
  export LAST_CMD
}
