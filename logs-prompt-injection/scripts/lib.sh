#!/usr/bin/env bash
# Shared helpers. The demos record what RBAC, approval, egress and audit do.
# They do not call a hosted model and they do not use real credentials.

if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "lib.sh must be sourced from bash" >&2
  exit 1
fi

export KIND_CLUSTER_NAME="logs-prompt-injection"
export KIND_CONTEXT="kind-${KIND_CLUSTER_NAME}"
export KIND_NODE_IMAGE="kindest/node:v1.34.11@sha256:44e222ee2132dab25ff87301682f89eb82c7880ea3a1bf543bfe9708fd08d67d"
export NGINX_REF="docker.io/library/nginx:1.28-alpine"
# Index digest. Docker on some runners records the amd64 manifest digest instead.
export NGINX_DIGEST="sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236"
export NGINX_AMD64_DIGEST="sha256:0dcc88822d45581e65ae329f8be769762bf628d3b2bb7d2a077d4aa5c98b30e3"
export PYTHON_REF="docker.io/library/python:3.13-alpine"
export PYTHON_DIGEST="sha256:79e7a9b9ff1cbceff819f856fb374477792a5967759d94df266de7b7b4120e6f"
export PYTHON_AMD64_DIGEST="sha256:f3ebba2ace255c93267a0278da88c7f1044432991abc4e6ad20d22e34dd0f8ee"
export DUMMY_VALUE="dummy-value-not-a-real-secret"
export CALICO_VERSION="v3.30.3"
export CALICO_SHA256="9382d2b27a76f40c170454b408653e6d71e2205ef0aef069e942bb690e7381d0"

require_kind_context() {
  local current err detail
  err=$(mktemp)
  if ! current=$(kubectl config current-context 2>"${err}"); then
    detail=$(tr '\n' ' ' < "${err}" || true)
    fail "refusing to continue: kubectl config current-context failed (${detail}). Expected context ${KIND_CONTEXT}."
  fi
  if [[ "${current}" != "${KIND_CONTEXT}" ]]; then
    fail "refusing to continue: kubectl context is '${current}', expected '${KIND_CONTEXT}'. These demos use that throw-away cluster and must not run against any other context."
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

SUMMARY_PATH=""

summary_open() {
  local slug="$1"
  local root="${ROOT:-.}"
  mkdir -p "${root}/summaries"
  SUMMARY_PATH="${root}/summaries/${slug}.md"
  : > "${SUMMARY_PATH}"
  trap 'summary_on_exit' EXIT
}

summary_switch() {
  local slug="$1"
  local root="${ROOT:-.}"
  mkdir -p "${root}/summaries"
  SUMMARY_PATH="${root}/summaries/${slug}.md"
  : > "${SUMMARY_PATH}"
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

format_cmd() {
  local out="" arg
  for arg in "$@"; do
    printf -v out '%s %q' "$out" "$arg"
  done
  printf '%s\n' "${out# }"
}

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

transcript_cmd_result() {
  local heading="$1"
  local command="$2"
  local file="$3"
  local rc="$4"
  transcript_block "${heading}" "${command}" "${file}"
  transcript "Exit ${rc}."
  transcript_blank
}

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
  # Callers in other scripts read these after transcript_exec returns.
  # shellcheck disable=SC2034
  TRANSCRIPT_RC="${rc}"
  # shellcheck disable=SC2034
  TRANSCRIPT_LOG="${log}"
}

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

assert_file_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if ! grep -q -F -- "$needle" "$file"; then
    fail "${message}"
  fi
}

assert_file_excludes() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if grep -q -F -- "$needle" "$file"; then
    fail "${message}"
  fi
}
