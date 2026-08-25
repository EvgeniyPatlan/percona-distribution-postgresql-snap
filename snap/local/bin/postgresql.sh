#!/bin/bash
set -euo pipefail

# Locale data ships inside the snap (percona-postgresql-18 depends on
# `locales | locales-all`, staged transitively); point glibc at it
# explicitly so initdb/postgres can see the locales they were built
# against. Mirrors charmed-postgresql-snap's start-patroni.sh, which needs
# this same LOCPATH export for the postgres process it launches.
export LOCPATH="${SNAP}/usr/lib/locale"

mapfile -t EXTRA_ARGS < <(snapctl get postgresql-args 2>/dev/null || true)

# For security measures, daemons should not be run as sudo.
# Execute postgres as the non-sudo user: snap_daemon.
exec "${SNAP}/usr/bin/setpriv" \
    --clear-groups \
    --reuid snap_daemon \
    --regid snap_daemon \
    -- \
    "${SNAP}/usr/lib/postgresql/18/bin/postgres" \
    -D "${SNAP_COMMON}/data" \
    -c config_file="${SNAP_DATA}/etc/postgresql/postgresql.conf" \
    "${EXTRA_ARGS[@]}"
