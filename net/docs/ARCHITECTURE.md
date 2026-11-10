# Architecture

## One-paragraph version

Each server runs an identical `net-monitor` daemon. Every `INTERVAL`
seconds it fires one `ping` at every peer in `servers.conf` plus
loopback, parses the summary, and appends one CSV row per probe to a
daily file under `/var/log/net/YYYY-MM-DD/ping-<source>.csv`. Nothing
talks to anything else — observations live on the node that made them,
and a fleet-wide view is just the union of those files.

## Why this shape

| Problem it avoids |
|---|
| **Central collector going down** — every node is self-contained. The log is useful standalone. |
| **Write contention** — one writer per file. No locking, no `flock`, no partial rows. |
| **Clock-skew ambiguity** — each row carries the source's own epoch; you compare rows from the same source without ever trusting fleet-wide clocks. |
| **Schema rot** — CSV + append-only + fixed header means every row in a file has the same shape, and new columns can only be appended. |

## Modules

```
+-----------------+       +------------------+
| bin/net-monitor | --->  | lib/pinger.sh    |  one probe -> (status, rtt, ttl, loss)
|  (daemon loop)  |       +------------------+
|                 |       | lib/logger.sh    |  CSV append + daily rotation
|                 |       +------------------+
|                 |       | lib/config.sh    |  load /etc/net/*.conf -> CFG_*
+-----------------+       +------------------+
                           | lib/common.sh   |  timestamps, hostname, die
                           +------------------+

+-----------------+       reads the same CSVs with awk filters
| bin/net-parse   | --->  tail / losses / summary / rtt
+-----------------+
```

Every lib file:

1. Has a load-guard (`__NET_<NAME>_SH_LOADED`) so double-sourcing is free.
2. Uses a namespace prefix on its public functions. Private helpers use
   `__` (double underscore).
3. Sources `common.sh` for shared primitives only — never another lib.
   That keeps the dependency graph a star, not a mesh.

## Daemon loop

```
loop:
  file = logger_ensure LOG_DIR SOURCE_NAME   # may roll to a new day
  if PING_SELF: probe(127.0.0.1) -> append
  for (name, addr) in targets:
      probe(addr) -> append
  logger_rotate LOG_DIR RETENTION_DAYS       # cheap find on day dirs
  sleep INTERVAL (in 1s chunks, SIGTERM-aware)
```

Sweep time ≈ `len(targets) * PING_TIMEOUT` in the worst case (all down).
Keep `INTERVAL` safely above that — the config comment spells this out.

## Install footprint

```
/opt/net/                 code              (owned by this repo on upgrade)
/etc/net/net.conf         operator config   (never overwritten after first install)
/etc/net/servers.conf     peer list         (never overwritten after first install)
/var/log/net/             data              (kept across upgrades; rotated by daemon)
/etc/systemd/system/net-monitor.service     (replaced on upgrade)
/usr/local/sbin/net-monitor  → /opt/net/bin/net-monitor
/usr/local/bin/net-parse     → /opt/net/bin/net-parse
```

## Extending it

- **Another probe type** (TCP connect, HTTP) → add `lib/tcp_prober.sh`
  with the same output contract as `pinger_probe`. `net-monitor` calls
  a prober; it doesn't care which one.
- **Another sink** (push to Loki, Prometheus textfile) → wrap
  `logger_write` behind a dispatch and keep CSV as the primary. Don't
  replace it — the local file is the source of truth if the network to
  your sink is the thing that broke.
- **Jitter / percentiles** → bump `PING_COUNT`, then post-process from
  the CSV. Keeping statistics out of the daemon keeps the daemon
  trivial.

## Non-goals

- Fleet-wide aggregation. Use `net-parse` on a box that has all CSVs,
  or push them into SQLite/DuckDB. The daemon never knows about peers'
  logs.
- Alerting. A separate cron that runs `net-parse --since-epoch … losses`
  and pipes to `mail` / Slack is five lines; keeping it out of the
  daemon keeps the daemon from being on an alerting critical path.
