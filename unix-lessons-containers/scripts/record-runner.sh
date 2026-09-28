#!/usr/bin/env bash
# Record the CI runner kernel, OS, and Docker security options.
set -euo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=SCRIPTDIR/lib.sh
source "${DIR}/lib.sh"

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
  if [[ -r /proc/sys/net/ipv4/ip_unprivileged_port_start ]]; then
    printf -- '- host ip_unprivileged_port_start: %s\n' "$(cat /proc/sys/net/ipv4/ip_unprivileged_port_start)"
  fi
  if [[ -r /sys/module/apparmor/parameters/enabled ]]; then
    printf -- '- apparmor enabled: %s\n' "$(tr -d '\0' < /sys/module/apparmor/parameters/enabled)"
  else
    printf -- '- apparmor enabled: file not present\n'
  fi
  if command -v docker >/dev/null 2>&1; then
    printf -- '- docker server: %s\n' "$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo unknown)"
    printf -- '- docker security: %s\n' "$(docker info --format '{{range .SecurityOptions}}{{.}} {{end}}' 2>/dev/null || echo unknown)"
  fi
  if command -v kubectl >/dev/null 2>&1; then
    printf -- '- kubectl: %s\n' "$(kubectl version --client=true 2>/dev/null | tr '\n' ' ')"
  fi
  if command -v kind >/dev/null 2>&1; then
    printf -- '- kind: %s\n' "$(kind version 2>/dev/null | tr '\n' ' ')"
  fi
  if command -v docker >/dev/null 2>&1 && docker inspect unix-lessons-control-plane >/dev/null 2>&1; then
    printf -- '- kind node privileged: %s\n' "$(docker inspect unix-lessons-control-plane --format '{{.HostConfig.Privileged}}')"
    printf -- '- kind node image: %s\n' "$(docker inspect unix-lessons-control-plane --format '{{.Config.Image}}')"
  fi
} > /tmp/runner-info.md
summary_file /tmp/runner-info.md
summary_blank
