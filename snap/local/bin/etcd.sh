#!/bin/bash
set -euo pipefail

mapfile -t EXTRA_ARGS < <(snapctl get etcd-args 2>/dev/null || true)

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
