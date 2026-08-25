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
done < <(snapctl get pgpool-args 2>/dev/null || true)

# pgpool decrypts pool_passwd's AES-encrypted entries (written by
# usr/sbin/pg_enc -m) using this key file; without it the running daemon
# cannot read any pool_passwd entry an operator generated with pg_enc,
# even though pg_enc itself succeeded (see pgpool.conf's comment block).
export PGPOOLKEYFILE="${SNAP_COMMON}/pgpool.key"

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
