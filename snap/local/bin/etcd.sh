#!/bin/bash
set -euo pipefail

# Under real snapd, `snapctl get` on an unset key prints one EMPTY line
# (an absent snapctl prints nothing), and a bare mapfile would hand the
# daemon a literal "" argument that aborts it at exec. Filter empty lines.
EXTRA_ARGS=()
while IFS= read -r arg; do
    if [ -n "${arg}" ]; then
        EXTRA_ARGS+=("${arg}")
    fi
done < <(snapctl get etcd-args 2>/dev/null || true)

# For security measures, daemons should not be run as sudo.
# Execute etcd as the non-sudo user: snap_daemon.
exec "${SNAP}/usr/bin/setpriv" \
    --clear-groups \
    --reuid snap_daemon \
    --regid snap_daemon \
    -- \
    "${SNAP}/usr/bin/etcd" \
    --config-file "${SNAP_DATA}/etc/etcd.conf.yml" \
    "${EXTRA_ARGS[@]}"
