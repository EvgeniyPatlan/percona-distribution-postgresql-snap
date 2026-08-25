#!/bin/bash
set -euo pipefail

# Structure copied from percona-distribution-mysql-pxc-snap's haproxy.sh:
# HAProxy runs fully unprivileged; -W keeps the master in the foreground
# for snapd. Config path is adapted to this snap's flat $SNAP_DATA/etc/
# template layout (dpkg-verified: percona-haproxy's own packaged config
# lives nested at etc/haproxy/haproxy.cfg, which this snap does not use —
# see snapcraft.yaml's organize block).
# Under real snapd, `snapctl get` on an unset key prints one EMPTY line
# (an absent snapctl prints nothing), and a bare mapfile would hand the
# daemon a literal "" argument that aborts it at exec. Filter empty lines.
EXTRA_ARGS=()
while IFS= read -r arg; do
    if [ -n "${arg}" ]; then
        EXTRA_ARGS+=("${arg}")
    fi
done < <(snapctl get haproxy-args 2>/dev/null || true)

exec "${SNAP}/usr/bin/setpriv" --clear-groups --reuid snap_daemon --regid snap_daemon -- \
    "${SNAP}/usr/sbin/haproxy" -W -f "${SNAP_DATA}/etc/haproxy.cfg" "${EXTRA_ARGS[@]}"
