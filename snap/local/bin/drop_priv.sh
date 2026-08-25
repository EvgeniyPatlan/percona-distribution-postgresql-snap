#!/bin/bash
set -euo pipefail

# Wrapper for _NAME_ CLI/ops tools: drops to the snap_daemon system user so
# PEER AUTH on the local socket lands on the auto-initialized postgres
# superuser role (see postgresql.conf/pg_hba.conf — no password needed).
#
# $1 is the absolute in-snap path to the target tool binary, e.g.:
#   bin/drop_priv.sh $SNAP/usr/lib/postgresql/18/bin/psql
# Unlike percona-server-mongodb-snap's drop_priv.sh (which appends a bare
# tool name onto $SNAP/usr/bin/), this one takes the full path: dpkg
# evidence shows percona-postgresql-client-18 ships its tools ONLY under
# usr/lib/postgresql/18/bin/ with no /usr/bin/* pg_wrapper symlinks
# (postgresql-client-common's alternatives are set up by a postinst
# maintainer script snapcraft never runs), so there is no fixed prefix to
# assume.
# libpq's compiled-in default socket directory on this Debian-style build
# is /var/run/postgresql, not this snap's unix_socket_directories
# ($SNAP_DATA/run, per postgresql.conf) — every client tool would need an
# explicit -h/--host on every invocation without this. Setting PGHOST here
# (not in postgresql.conf, which only controls the server) makes the
# description's "connect immediately" promise (sudo <snap>.psql, no -h)
# actually true; an explicit -h/--host on the command line still wins over
# this env default, same as any other libpq env var.
export PGHOST="${SNAP_DATA}/run"
# libpq also defaults the target database name to the OS/session
# username -- snap_daemon here, which is not a real database (initdb only
# creates "postgres"/"template0"/"template1"). Without this, even a
# correctly-PGHOST'd `sudo <snap>.psql` fails with `database "snap_daemon"
# does not exist`. An explicit dbname argument or -d/--dbname still wins.
export PGDATABASE="postgres"

# pgbadger (the one perl script routed through this wrapper) fails with
# "Can't locate Benchmark.pm in @INC" without this -- core26 ships no
# system perl, so pgbadger's own interpreter/modules are staged inside
# the snap, but perl's compiled-in default @INC only knows host paths.
# Glob-based (not version-pinned) to match percona-distribution-mysql-ps-
# snap's pt-tool.sh precedent; harmless no-op for every non-perl tool
# this wrapper also launches (psql, pgbackrest, ...).
plib=""
for d in "${SNAP}"/usr/lib/*/perl-base \
         "${SNAP}"/usr/lib/*/perl5/* \
         "${SNAP}"/usr/share/perl5 \
         "${SNAP}"/usr/lib/*/perl/* \
         "${SNAP}"/usr/share/perl/*; do
    [ -d "${d}" ] && plib="${plib:+${plib}:}${d}"
done
export PERL5LIB="${plib}${PERL5LIB:+:${PERL5LIB}}"

exec "${SNAP}/usr/bin/setpriv" \
    --clear-groups \
    --reuid snap_daemon \
    --regid snap_daemon \
    -- \
    "$@"
