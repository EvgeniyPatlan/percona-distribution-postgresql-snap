# percona-distribution-postgresql

Percona Distribution for PostgreSQL packaged as a strict-confinement snap:
PostgreSQL 17 plus every extension, backup/pooling tool, and HA component
Percona ships — pg_tde (transparent data encryption), pg_stat_monitor,
pgAudit (+ set_user), pgvector, pg_cron, pg_repack, wal2json, pgBackRest,
PgBouncer, pgBadger, pg_gather, Patroni, etcd, HAProxy, Pgpool-II, and
PostGIS plus the PL/Perl, PL/Python3, and PL/Tcl procedural languages —
staged unmodified from Percona's official apt repository at
`repo.percona.com`, nothing compiled from source. Two major versions are
published as separate branches/tracks, each pinned to an exact upstream
package version (see below). Base: `core26`.

## Why this snap

One artifact instead of assembling server, extensions, backup, pooling,
and HA tooling from separate packages, every component pinned to an
exact upstream version. The install hook runs `initdb` and starts
`postgres` automatically, already reachable as the superuser with no
password (see First steps). PgBouncer, Patroni, etcd, HAProxy, and
Pgpool-II ship as disabled daemons, opt in with `snap start`. Each
supported major (18, 17) is a distinct branch/track — moving to a new
major is an explicit channel switch.

## Tracks and branches

| Branch | apt source | Version |
|---|---|---|
| `18/edge` | `repo.percona.com/ppg-18/apt` (resolute, main) | 18.6-1 |
| `17/edge` | `repo.percona.com/ppg-17/apt` (resolute, main) | 17.11-1 |

- **JIT**: separate `percona-postgresql-18-jit` package on 18; on 17
  it's built into core `percona-postgresql-17` (`Provides:
  postgresql-17-jit-llvm`) — no extra pin needed.
- **pg_tde**: `percona-pg-tde18` is pulled in only by this snap's pin on
  18; on 17, `percona-pg-tde17` is also a hard `Depends` of core
  `percona-postgresql-17` — still pinned explicitly here.
- **pg_gather**: most ops/HA packages (pgBackRest, PgBouncer, pgBadger,
  Patroni, etcd, HAProxy, Pgpool-II) are byte-identical across tracks,
  but `percona-pg-gather` depends on `percona-postgresql-<major>`, so it
  tracks the PG-major repo (`33-3` on 18, `33-2` on 17).

This snap is not yet published to the Snap Store — get it from a CI
build or a local `snapcraft pack`.

## Getting the snap

Every push to a `*/edge` branch, every pull request, and every manual
`Tests` workflow run builds the snap (amd64 + arm64) and runs the full
spread suite against it. The release workflow (Snap Store publish) only
runs once the repository's `RELEASE_ENABLED` variable is set, so a CI
or local build is currently the only way to get this snap.

**From a CI build:** open the workflow run in GitHub Actions, download
the `snap-packages` artifact, unzip it, then:
```
sudo snap install ./percona-distribution-postgresql_<version>_amd64.snap --dangerous --jailmode
```

**From source:**
```
git clone https://github.com/EvgeniyPatlan/percona-distribution-postgresql-snap.git
cd percona-distribution-postgresql-snap
git checkout 18/edge   # or 17/edge
snapcraft pack
sudo snap install ./percona-distribution-postgresql_*.snap --dangerous --jailmode
```

Requires the `snapcraft` and `lxd` snaps.

## First steps

`postgres` initializes its data directory (`initdb`) and starts
automatically on install. Connect as the superuser immediately, no
password:

```
sudo percona-distribution-postgresql.psql
```

Every client wrapper drops privileges to `snap_daemon` before connecting
over the local Unix socket, and `pg_hba.conf`'s `local ... peer` line
trusts that OS user unconditionally. TCP (`127.0.0.1:5432`) is not
covered by peer auth — it needs a role with a password (`pg_hba.conf`'s
`host` line requires `scram-sha-256`):

```
sudo percona-distribution-postgresql.psql -c "CREATE ROLE myrole LOGIN PASSWORD 'mypassword';"
```

Two confinement quirks apply to every client command: redirecting stdout
needs `| cat` appended (e.g.
`percona-distribution-postgresql.pg-dump postgres | cat > backup.sql`),
and input files (`COPY FROM`, pgBackRest repos, pgbadger logs, ...) must
live under `/var/snap/percona-distribution-postgresql/common` — the
snap cannot read your home directory under strict confinement.

## Services and apps

| App | Kind | Purpose |
|---|---|---|
| `postgresql` | daemon, auto-started | postgres server, `127.0.0.1:5432` |
| `pgbouncer` | daemon, disabled | connection pooler, `127.0.0.1:6432` |
| `patroni` | daemon, disabled | HA cluster manager, own scratch cluster on `127.0.0.1:5433` |
| `etcd` | daemon, disabled | single-node DCS backing Patroni, `127.0.0.1:2379` (peers `:2380`) |
| `haproxy` | daemon, disabled | TCP-mode load balancer, stats socket in `$SNAP_DATA/run` |
| `pgpool` | daemon, disabled | pooling/load balancing, `127.0.0.1:9999` (PCP `:9898`) |
| `psql` | CLI | interactive/batch SQL client |
| `pg-dump` / `pg-dumpall` | CLI | logical backup (one database / whole cluster) |
| `pg-restore` | CLI | restore from a `pg_dump` archive |
| `pg-basebackup` | CLI | physical base backup |
| `pgbench` | CLI | benchmark tool |
| `createdb` / `dropdb` | CLI | database create/drop |
| `createuser` / `dropuser` | CLI | role create/drop |
| `pg-isready` | CLI | connection/readiness check |
| `vacuumdb` / `reindexdb` / `clusterdb` | CLI | VACUUM/REINDEX/CLUSTER from the shell |
| `pg-repack` | CLI | online table/index bloat removal |
| `pgbackrest` | CLI | backup/restore/archive management |
| `pgbadger` | CLI | PostgreSQL log analyzer |
| `pg-gather` | CLI | runs Percona's `gather.sql` diagnostic script |

`postgresql` is the only daemon enabled by default (`sudo snap
stop|start|restart percona-distribution-postgresql.postgresql`).
`pgbouncer`, `patroni`, `etcd`, `haproxy`, and `pgpool` ship
`install-mode: disable` — present on disk after install, not running
until `snap start`.

## Configuration and data paths

| Item | Path |
|---|---|
| postgres config | `.../current/etc/postgresql/postgresql.conf` |
| Client-auth config | `.../current/etc/postgresql/pg_hba.conf` |
| PgBouncer config / auth file | `.../etc/pgbouncer.ini` / `.../etc/pgbouncer-userlist.txt` (empty until you add roles) |
| Patroni / etcd config | `.../etc/patroni.yml` / `.../etc/etcd.conf.yml` |
| HAProxy / Pgpool-II config | `.../etc/haproxy.cfg` / `.../etc/pgpool.conf` |
| pgBackRest config | `.../etc/pgbackrest.conf` |
| Data directory | `/var/snap/.../common/data` (survives refreshes) |
| Log / unix socket dirs | `/var/snap/.../common/log` / `/var/snap/.../current/run` |
| pg_tde keyring dir | `.../common/pg_tde_keyring` (created by the install hook) |
| pgBackRest repo | `/var/snap/.../common/pgbackrest` |
| Patroni scratch cluster | `/var/snap/.../common/patroni-data` |

(`...` = `percona-distribution-postgresql`.) All templates are seeded
into `$SNAP_DATA/etc` on install (cp-if-absent, a refresh never clobbers
an edit). Edit the seeded copy, then
`sudo snap restart percona-distribution-postgresql.<app>`.

## Preloaded extensions and the CREATE EXTENSION set

`shared_preload_libraries` loads four extensions on every start:
`pg_tde`, `pg_stat_monitor`, `pgaudit`, `pg_cron`. Everything else ships
ready for a plain `CREATE EXTENSION`; the smoke suite proves at least
`pg_tde`, `vector` (pgvector), `pg_stat_monitor`, `pgaudit`, `pg_cron`,
`postgis`, `plpython3u`, and `set_user`. `pg_repack` and `wal2json` are
also staged — `wal2json` is the exception: it ships as a
logical-decoding **output plugin**, selected via
`pg_recvlogical --plugin=wal2json` or
`pg_create_logical_replication_slot('slot', 'wal2json')`, not
`CREATE EXTENSION`.

```
sudo percona-distribution-postgresql.psql -c "CREATE EXTENSION vector;"
sudo percona-distribution-postgresql.psql -c "CREATE EXTENSION postgis;"
```

## pg_tde: transparent data encryption

The install hook seeds `.../common/pg_tde_keyring`, owned by
`snap_daemon` (pg_tde writes the keyring file from inside the server,
not the client). Set up a file keyring, then create an encrypted table —
the real 3-call flow, in order (skipping "create" fails with
`key ... does not exist`):

```
sudo percona-distribution-postgresql.psql -c "CREATE EXTENSION pg_tde;"
sudo percona-distribution-postgresql.psql -c "SELECT pg_tde_add_global_key_provider_file('file-keyring', '/var/snap/percona-distribution-postgresql/common/pg_tde_keyring/keyring');"
sudo percona-distribution-postgresql.psql -c "SELECT pg_tde_create_key_using_global_key_provider('principal-key', 'file-keyring');"
sudo percona-distribution-postgresql.psql -c "SELECT pg_tde_set_key_using_global_key_provider('principal-key', 'file-keyring');"
sudo percona-distribution-postgresql.psql -c "CREATE TABLE secret_probe (id INT PRIMARY KEY, v TEXT) USING tde_heap;"
```

A file keyring is a starting point, not a production keyring — see
Percona's pg_tde documentation before using this for production data.

## pgBackRest

`archive_mode` is on and `archive_command` is pre-wired in
`postgresql.conf`, but it's a guarded no-op: every WAL switch checks
whether the repo's `archive.info` exists and exits 0 if not, so a
default install never backlogs against a nonexistent stanza.
`PGBACKREST_CONFIG` is set on both the `postgresql` and `pgbackrest`
apps, so `--config` is never required:

```
sudo percona-distribution-postgresql.pgbackrest --stanza=main stanza-create
sudo percona-distribution-postgresql.pgbackrest --stanza=main --type=full backup
sudo percona-distribution-postgresql.pgbackrest --stanza=main info
```

Restores work out of the box — stop `postgresql`, clear the data
directory, restore, start `postgresql` again; the config's
`recovery-option` pins `restore_command` to the `current` snap-mount
path (not a revision-pinned one), so it survives refreshes:

```
sudo snap stop percona-distribution-postgresql.postgresql
sudo rm -rf /var/snap/percona-distribution-postgresql/common/data/*
sudo percona-distribution-postgresql.pgbackrest --stanza=main restore
sudo snap start percona-distribution-postgresql.postgresql
```

## PgBouncer

`sudo snap start percona-distribution-postgresql.pgbouncer` — listens on
`127.0.0.1:6432`, `auth_type = scram-sha-256`. `auth_file` starts empty;
add a role's scram secret, and a `[databases]` entry routed over TCP
(`host=127.0.0.1 port=5432`, not the unix socket — `pg_hba.conf`'s
`local ... peer` line only ever matches `snap_daemon` by OS username),
before it can authenticate anyone:

```
SECRET=$(sudo percona-distribution-postgresql.psql -tAc "SELECT rolpassword FROM pg_authid WHERE rolname = 'myrole';")
echo "\"myrole\" \"${SECRET}\"" | sudo tee -a /var/snap/percona-distribution-postgresql/current/etc/pgbouncer-userlist.txt
```

## HA stack: Patroni, etcd, HAProxy, Pgpool-II

All four ship disabled. Patroni manages its **own** scratch postgres
cluster under `common/patroni-data` (port `5433`), separate from the
`postgresql` app's data directory — stop `postgresql` first:

```
sudo snap stop percona-distribution-postgresql.postgresql
sudo snap start percona-distribution-postgresql.etcd
sudo snap start percona-distribution-postgresql.patroni
```

etcd's health endpoint is `http://127.0.0.1:2379/health`; Patroni's REST
API is `127.0.0.1:8008`. `patronictl` has no snap app wrapper — it's a
setuptools entry-point shim, so it needs its site tree on `PYTHONPATH`
(and `LOCPATH` for locale data) to import anything, the same env
`bin/patroni.sh` sets up for the daemon itself:

```
SNAP_CUR=/snap/percona-distribution-postgresql/current
export PYTHONPATH="${SNAP_CUR}/usr/lib/python3/dist-packages"
export LOCPATH="${SNAP_CUR}/usr/lib/locale"
"${SNAP_CUR}/usr/bin/patronictl" \
  -c /var/snap/percona-distribution-postgresql/current/etc/patroni.yml list
```

HAProxy ships no enabled frontend/backend. `haproxy.cfg`'s commented-out
example uses `option pgsql-check`, a protocol-aware check — the
`haproxy_service` suite avoids that (a known TCP-close race pairing it
with a script-based responder) and uses a plain TCP connect check
instead:

```
frontend postgres-front
    bind 127.0.0.1:5000
    default_backend postgres-back

backend postgres-back
    server node1 127.0.0.1:5432 check inter 2s downinter 2s rise 2 fall 3
```

Append that (plus a `stats socket` line in `global`) to `haproxy.cfg`,
then `snap start percona-distribution-postgresql.haproxy`.

Pgpool-II is wired to this snap's own postgres by default but needs: (1)
`sr_check_user`/`health_check_user` (+ passwords) in `pgpool.conf` — it
cannot authenticate to the backend without these; (2) a key file at
`.../common/pgpool.key`, mode `0600`, owned by `snap_daemon` — the
daemon's wrapper exports `PGPOOLKEYFILE` at this fixed path; (3) a
`pool_passwd` entry from `pg_enc` (not `pg_md5` — the backend requires
scram), keyed with that same file:

```
printf 'pgpoolkey' | sudo tee /var/snap/percona-distribution-postgresql/common/pgpool.key
sudo chmod 0600 /var/snap/percona-distribution-postgresql/common/pgpool.key
sudo chown snap_daemon:root /var/snap/percona-distribution-postgresql/common/pgpool.key
sudo PGPOOLKEYFILE=/var/snap/percona-distribution-postgresql/common/pgpool.key \
  /snap/percona-distribution-postgresql/current/usr/sbin/pg_enc -m -u myrole \
  -f /var/snap/percona-distribution-postgresql/current/etc/pgpool.conf 'mypassword'
sudo chown snap_daemon:root /var/snap/percona-distribution-postgresql/current/etc/pool_passwd
sudo snap start percona-distribution-postgresql.pgpool
```

## pgBadger and pg_gather

```
sudo percona-distribution-postgresql.pgbadger /var/snap/percona-distribution-postgresql/common/log/postgresql-*.log
sudo percona-distribution-postgresql.pg-gather | cat > gather_output.txt
```

`pg-gather` ships no binary — it runs Percona's `gather.sql` diagnostic
script through `psql -f` against this snap's own postgres.

## Removal

```
sudo snap remove percona-distribution-postgresql --purge --terminate
```

`--purge` also removes `/var/snap/percona-distribution-postgresql`,
including the data directory.

## Testing

Every push and pull request runs the full spread suite against a real
snapd install inside an LXD `ubuntu-24.04` VM, on `amd64` and `arm64`.
Suites: `smoke`, `backup_restore`, `cli_tools`, `daemon_postgresql`,
`pgbouncer_service`, `patroni_etcd`, `haproxy_service`, `pgpool_service`,
and `upgrade` (`manual` until published to `17/edge`).

```
snapcraft pack
CRAFT_ARTIFACT=$(pwd)/percona-distribution-postgresql_<version>_amd64.snap spread -v
```

(`spread` from `go install github.com/canonical/spread/cmd/spread@latest`;
needs the `lxd` snap.)

## License

The snap packaging is Apache-2.0 (see `LICENSE`). Upstream component
licenses for every staged package (PostgreSQL, pg_tde, pgBackRest,
Patroni, PostGIS, and the rest) are shipped under `licenses/` inside the
snap.
