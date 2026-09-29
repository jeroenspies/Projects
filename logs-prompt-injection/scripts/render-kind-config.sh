#!/usr/bin/env bash
# Write a kind config with an absolute path to the audit policy.
# Usage: render-kind-config.sh DEST kindnet|calico
set -euo pipefail

if [[ $# -ne 2 ]]; then
  printf 'usage: render-kind-config.sh DEST kindnet|calico\n' >&2
  exit 1
fi

dest="$1"
mode="$2"
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "${script_dir}/.." && pwd)
policy="${root}/audit-policy.yaml"
tmpl="${root}/kind-config.yaml.tmpl"

if [[ ! -f "${policy}" || ! -f "${tmpl}" ]]; then
  printf 'missing audit policy or kind config template\n' >&2
  exit 1
fi

networking=""
case "${mode}" in
  kindnet) ;;
  calico)
    networking=$'networking:\n  disableDefaultCNI: true\n  podSubnet: 192.168.0.0/16'
    ;;
  *)
    printf 'unknown mode: %s\n' "${mode}" >&2
    exit 1
    ;;
esac

python3 - "${tmpl}" "${dest}" "${policy}" "${networking}" <<'PY'
import pathlib, sys
src, dest, policy, networking = sys.argv[1:]
text = pathlib.Path(src).read_text(encoding="utf-8")
text = text.replace("__AUDIT_POLICY_HOST_PATH__", policy)
if networking:
    text = text.replace("__NETWORKING__\n", networking + "\n")
else:
    text = text.replace("__NETWORKING__\n", "")
pathlib.Path(dest).write_text(text, encoding="utf-8")
PY
