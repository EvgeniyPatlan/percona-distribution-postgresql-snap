#!/bin/bash
set -euo pipefail

mapfile -t EXTRA_ARGS < <(snapctl get pgpool-args 2>/dev/null || true)

# For security measures, daemons should not be run as sudo.
# Execute pgpool as the non-sudo user: snap_daemon.
# -n keeps pgpool in the foreground for snapd's supervision.
exec "${SNAP}/usr/bin/setpriv" \
    --clear-groups \
    --reuid snap_daemon \
    --regid snap_daemon \
    -- \
    "${SNAP}/usr/sbin/pgpool" \
    -n \
    -f "${SNAP_DATA}/etc/pgpool.conf" \
    "${EXTRA_ARGS[@]}"
