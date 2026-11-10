# Log format

## File path

```
$LOG_DIR/YYYY-MM-DD/ping-<source-hostname>.csv
```

- `YYYY-MM-DD` is **UTC**. A new file is opened at the first probe after
  00:00 UTC each day — `logger_ensure` checks this on every write, so the
  rollover is automatic.
- `<source-hostname>` is the value of `SOURCE_NAME` in `/etc/net/net.conf`,
  defaulting to `hostname -s`. One file per source means no cross-host
  writer contention and trivial parallel parsing.
- Older day-directories are deleted by `logger_rotate` when they are
  older than `LOG_RETENTION_DAYS` days (mtime-based). Set it to `0` to
  keep forever.

## Columns

CSV, comma-separated, header on the first line of every file:

```
ts_iso,ts_epoch,source,target_name,target_addr,status,rtt_ms,ttl,loss_pct
```

| Column | Type | Notes |
|---|---|---|
| `ts_iso`      | ISO-8601 UTC, ms precision (`2026-11-10T04:05:06.789Z`) | For humans. |
| `ts_epoch`    | integer seconds                       | For range filters. `net-parse --since-epoch`. |
| `source`      | string                                | The host writing the row. |
| `target_name` | string                                | Label from `servers.conf`. `self` for the loopback probe. |
| `target_addr` | string                                | IP or hostname probed. |
| `status`      | enum                                  | `ok` / `timeout` / `unreachable` / `error`. |
| `rtt_ms`      | float or empty                        | Average RTT across `PING_COUNT` probes. Empty on `timeout`/`unreachable`. |
| `ttl`         | always empty                          | Reserved. `ping -q` gives summary only; see note below. |
| `loss_pct`    | integer 0–100 or empty                | `%` packet loss in the sweep. `100` on total timeout. |

Fields never contain commas or newlines by construction — `target_name`
must be shell-safe (no spaces) and all other columns are generated
timestamps, enums, or numeric.

### Why `ttl` is empty

`ping -q` prints a summary only, which is cheap and enough for alerting
on loss / latency. TTL is a per-reply field; capturing it forces parsing
every reply line and roughly doubles the shell work per probe. If you
need TTL, change `pinger_probe` in `lib/pinger.sh` to drop `-q`, parse
the `ttl=` out of each reply, and write the mode.

## Parsing recipes

**Rows for one pair, today:**

```bash
net-parse --date today --source web-01 --target db-01 tail
```

**All losses in the last hour:**

```bash
net-parse --since-epoch "$(date -u -d '1 hour ago' +%s)" losses
```

**Import a day into SQLite:**

```bash
sqlite3 net.db <<'SQL'
.mode csv
.import /var/log/net/2026-11-10/ping-web-01.csv ping
CREATE INDEX ping_idx ON ping(target_name, ts_epoch);
SQL
```

**Fleet view** — rsync every node's CSV to one box and run `net-parse`
with no `--source` filter. Each row already carries its source.

## Stability

The schema is additive-only: new columns will be appended on the right.
A reader that pins the first nine columns and ignores the rest will keep
working across versions.
