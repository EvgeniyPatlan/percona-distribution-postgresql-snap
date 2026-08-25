#!/bin/bash
set -euo pipefail

# core26 ships no python3 by default; percona-patroni's own dependency
# chain (python3-click, python3-psycopg2, python3-etcd, ...) pulls the
# interpreter and its site tree in transitively, and this snap stages
# `python3` explicitly too (same defensive precedent as the pt-tool.sh
# PERL5LIB glob: don't assume the exact interpreter/version directory).
plib=""
for d in "${SNAP}"/usr/lib/python3/dist-packages \
         "${SNAP}"/usr/lib/python3.*/dist-packages \
         "${SNAP}"/usr/lib/python3.*/site-packages; do
    [ -d "${d}" ] && plib="${plib:+${plib}:}${d}"
done
export PYTHONPATH="${plib}${PYTHONPATH:+:${PYTHONPATH}}"

# Locale data (see postgresql.sh) — patroni execs postgres itself when it
# manages its own (scratch) cluster, so the same LOCPATH must reach it here.
export LOCPATH="${SNAP}/usr/lib/locale"

# Under real snapd, `snapctl get` on an unset key prints one EMPTY line
# (an absent snapctl prints nothing), and a bare mapfile would hand the
# daemon a literal "" argument that aborts it at exec. Filter empty lines.
EXTRA_ARGS=()
while IFS= read -r arg; do
    if [ -n "${arg}" ]; then
        EXTRA_ARGS+=("${arg}")
    fi
done < <(snapctl get patroni-args 2>/dev/null || true)

# For security measures, daemons should not be run as sudo.
# Execute patroni as the non-sudo user: snap_daemon.
exec "${SNAP}/usr/bin/setpriv" \
    --clear-groups \
    --reuid snap_daemon \
    --regid snap_daemon \
    -- \
    "${SNAP}/usr/bin/patroni" \
    "${SNAP_DATA}/etc/patroni.yml" \
    "${EXTRA_ARGS[@]}"
