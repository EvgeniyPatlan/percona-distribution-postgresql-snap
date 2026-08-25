#!/bin/bash
set -euo pipefail

mapfile -t EXTRA_ARGS < <(snapctl get pgbouncer-args 2>/dev/null || true)

# For security measures, daemons should not be run as sudo.
# Execute pgbouncer as the non-sudo user: snap_daemon.
exec "${SNAP}/usr/bin/setpriv" \
    --clear-groups \
    --reuid snap_daemon \
    --regid snap_daemon \
    -- \
    "${SNAP}/usr/sbin/pgbouncer" \
    "${SNAP_DATA}/etc/pgbouncer.ini" \
    "${EXTRA_ARGS[@]}"
