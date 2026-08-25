#!/bin/bash
set -euo pipefail

# Structure copied from percona-distribution-mysql-pxc-snap's haproxy.sh:
# HAProxy runs fully unprivileged; -W keeps the master in the foreground
# for snapd. Config path is adapted to this snap's flat $SNAP_DATA/etc/
# template layout (dpkg-verified: percona-haproxy's own packaged config
# lives nested at etc/haproxy/haproxy.cfg, which this snap does not use —
# see snapcraft.yaml's organize block).
mapfile -t EXTRA_ARGS < <(snapctl get haproxy-args 2>/dev/null || true)

exec "${SNAP}/usr/bin/setpriv" --clear-groups --reuid snap_daemon --regid snap_daemon -- \
    "${SNAP}/usr/sbin/haproxy" -W -f "${SNAP_DATA}/etc/haproxy.cfg" "${EXTRA_ARGS[@]}"
