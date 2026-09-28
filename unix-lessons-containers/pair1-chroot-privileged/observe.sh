#!/bin/sh
# Print capability, device, and mount observations. Writes id(1) inside the container.
set -eu

id > /tmp/id-proof

cap_hex=$(awk '/^CapEff:/ {print $2}' /proc/self/status)
cap_bnd=$(awk '/^CapBnd:/ {print $2}' /proc/self/status)
cap_amb=$(awk '/^CapAmb:/ {print $2}' /proc/self/status)
cap_prm=$(awk '/^CapPrm:/ {print $2}' /proc/self/status)
nnp=$(awk '/^NoNewPrivs:/ {print $2}' /proc/self/status)
decoded=$(capsh --decode="$cap_hex")
# ls is the observation the demo records (count of /dev entries), not a filename iterator.
# shellcheck disable=SC2012
dev_count=$(ls -1 /dev | wc -l | tr -d ' ')
mount_count=$(wc -l < /proc/self/mounts | tr -d ' ')

echo "OBS ID=$(cat /tmp/id-proof)"
# Full Cap* lines from /proc/self/status, one observation per line.
grep '^Cap' /proc/self/status | while IFS= read -r line; do
    echo "OBS CAPLINE ${line}"
done
echo "OBS CAPEFF_HEX=$cap_hex"
echo "OBS CAPPRM_HEX=$cap_prm"
echo "OBS CAPBND_HEX=$cap_bnd"
echo "OBS CAPAMB_HEX=$cap_amb"
echo "OBS CAPEFF_DECODED=$decoded"
echo "OBS NONEWPRIVS=$nnp"
echo "OBS DEV_COUNT=$dev_count"
echo "OBS MOUNT_COUNT=$mount_count"

if [ -r /proc/sys/net/ipv4/ip_unprivileged_port_start ]; then
    echo "OBS UNPRIV_PORT_START=$(cat /proc/sys/net/ipv4/ip_unprivileged_port_start)"
fi

if [ -r /proc/self/attr/current ]; then
    apparmor=$(tr -d '\0' < /proc/self/attr/current || true)
    echo "OBS APPARMOR=${apparmor:-unknown}"
fi

echo "OBS ID_FILE_WRITTEN=/tmp/id-proof"
