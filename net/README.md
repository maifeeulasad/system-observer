# net — interconnectivity monitor

Bash-only, Ubuntu-first. Every N seconds each node pings every other node
(and itself) and appends one CSV row per probe to a daily log file.

```
your-fleet-wide view = union of every node's own ping log
```

## Quick start (per server)

```bash
git clone https://github.com/<you>/system-observer.git
cd system-observer/net
sudo ./install.sh
sudoedit /etc/net/servers.conf       # add one 'name ip' per line
sudo systemctl start net-monitor
net-parse --date today summary
```

## What you get

| Path | What it is |
|---|---|
| `/opt/net`                        | code (owned by the repo; replaced on upgrade) |
| `/etc/net/net.conf`               | interval, log dir, retention |
| `/etc/net/servers.conf`           | list of peers — the one file you actually edit |
| `/var/log/net/YYYY-MM-DD/ping-<host>.csv` | one CSV per day per source host |
| `systemctl status net-monitor`    | daemon status |
| `net-parse …`                     | query the logs |

## Layout

```
net/
├── bin/
│   ├── net-monitor       # daemon — sweeps targets every INTERVAL seconds
│   └── net-parse         # query the logs (tail / summary / losses / rtt)
├── lib/
│   ├── common.sh         # timestamps, hostname, stderr logger
│   ├── config.sh         # loads net.conf + servers.conf into CFG_*
│   ├── logger.sh         # CSV writer + daily file rotation
│   └── pinger.sh         # one-shot ping + output parser
├── config/
│   ├── net.conf.example
│   └── servers.conf.example
├── systemd/
│   └── net-monitor.service
├── docs/
│   ├── LOG_FORMAT.md
│   └── ARCHITECTURE.md
├── install.sh
├── upgrade.sh
└── uninstall.sh
```

Each lib is a "class": a prefix (`config_*`, `logger_*`, `pinger_*`), a load
guard, and no global side effects at source time. Entrypoints in `bin/`
compose them. That's the OOP shape — bash doesn't give you more, and
pretending it does bites you later.

## Upgrade

```bash
cd system-observer && git pull
sudo ./net/upgrade.sh
```

`upgrade.sh` won't touch `/etc/net/*.conf` or `/var/log/net`, and restarts
the service only if it was already running.

## Why CSV, not JSON?

- `awk -F,` is in base Ubuntu; `jq` isn't always.
- The schema is fixed, so field names in every row would just be bloat.
- Imports into SQLite / DuckDB / pandas are one line.

See [docs/LOG_FORMAT.md](docs/LOG_FORMAT.md) for columns and parsing tips,
and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the pieces fit.

## Caveats

- ping RTT precision depends on `iputils-ping`'s summary line; we take the
  avg of `-c PING_COUNT` probes. Bump `PING_COUNT` for smoother numbers.
- All timestamps are **UTC**. Convert at read time if you need local.
- One source host, one writer: logs are append-only and never read by the
  daemon, so no locking is needed.
- Clock skew across your fleet will show up as skew in the logs. Run
  `chrony` or `systemd-timesyncd` — you want this anyway.
