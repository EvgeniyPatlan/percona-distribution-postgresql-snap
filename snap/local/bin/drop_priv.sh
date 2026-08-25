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
exec "${SNAP}/usr/bin/setpriv" \
    --clear-groups \
    --reuid snap_daemon \
    --regid snap_daemon \
    -- \
    "$@"
