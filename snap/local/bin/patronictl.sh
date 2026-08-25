#!/bin/bash
set -euo pipefail

# patronictl must run on the snap's OWN python: the staged site tree is
# built for core26's interpreter, and its C extensions (psycopg2's
# cpython-313 .so) are invisible to any other python version -- CI-proven
# on a noble host (python 3.12): the patroni daemon held the leader lock
# while a host-python patronictl died with "No module named 'psycopg'".
# Same PYTHONPATH/LOCPATH setup as patroni.sh, for the same reasons.
plib=""
for d in "${SNAP}"/usr/lib/python3/dist-packages \
         "${SNAP}"/usr/lib/python3.*/dist-packages \
         "${SNAP}"/usr/lib/python3.*/site-packages; do
    [ -d "${d}" ] && plib="${plib:+${plib}:}${d}"
done
export PYTHONPATH="${plib}${PYTHONPATH:+:${PYTHONPATH}}"
export LOCPATH="${SNAP}/usr/lib/locale"

exec "${SNAP}/usr/bin/setpriv" \
    --clear-groups \
    --reuid snap_daemon \
    --regid snap_daemon \
    -- \
    "${SNAP}/usr/bin/python3" "${SNAP}/usr/bin/patronictl" "$@"
