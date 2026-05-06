# home_automation

> Home server automation scripts for **brak** and **zorak** — two Linux file servers running ZFS storage pools.

Personal scripts that keep the lights on. Currently focused on automated backups, with room to grow.

---

## What's in here

| File | Purpose |
| --- | --- |
| [`backup-data`](./backup-data) | Backup script. Syncs `/data-1` and `/data-2` to local pool `/data-3` and to a remote host. Follows [Command Line Interface Guidelines](https://clig.dev). |
| `LICENSE` | MIT |

---

## The setup it backs up

Two Ubuntu 22.04 servers, both running ZFS:

```
brak (10.1.1.20)                           zorak (10.1.1.30)
├── /data-1   primary  (ZFS mirror)        ├── /data-1   backup of brak's
├── /data-2   primary  (ZFS mirror)        └── /data-2   backup of brak's
└── /data-3   local backup of 1 & 2
```

Nightly cron on **brak** runs `backup-data`, which:

1. rsyncs `/data-1` → `/data-3/data-1`
2. rsyncs `/data-2` → `/data-3/data-2`
3. rsyncs `/data-1` → `zorak:/data-1`
4. rsyncs `/data-2` → `zorak:/data-2`

That gives three copies of every file: original + local backup + remote backup.

---

## Install

```bash
# Clone (on brak)
git clone https://github.com/mickmill54/home_automation.git
cd home_automation

# Copy to a standard PATH location
sudo install -m 755 backup-data /usr/local/bin/

# Verify
backup-data --version
backup-data --help

# Test a dry run
backup-data --dry-run --verbose
```

Set up the cron schedule once, in `/etc/cron.d/backup-data`:

```
# Nightly backup at 2:00 AM
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

0 2 * * *  mick  /usr/local/bin/backup-data --quiet
```

(Or use `crontab -e` if you prefer user crontabs. `/etc/cron.d/` is plain text, version-controllable, and the user field is explicit — fewer surprises.)

---

## Usage

### Synopsis

```
backup-data [OPTIONS]
backup-data --help
backup-data --version
```

### Options

| Flag | Description |
| --- | --- |
| `-n`, `--dry-run` | Preview what would be transferred without doing it |
| `-v`, `--verbose` | More detailed output (`-vv` for debug-level) |
| `-q`, `--quiet` | Suppress informational output (errors still print) |
| `--no-local` | Skip the local backup to `/data-3` |
| `--no-remote` | Skip the remote backup to zorak |
| `--no-color` | Disable colored output (also honors `$NO_COLOR`) |
| `--log-dir DIR` | Override log directory |
| `--remote-host HOST` | Override remote host (format: `user@host`) |
| `-h`, `--help` | Show help and exit |
| `-V`, `--version` | Show version and exit |

### Environment variables

All flags can also be set via environment variables:

| Variable | Description | Default |
| --- | --- | --- |
| `BACKUP_LOG_DIR` | Where to write log files | `/home/mick/logs` |
| `BACKUP_LOG_RETENTION_DAYS` | Days to keep logs | `30` |
| `BACKUP_REMOTE_HOST` | Remote SSH target | `mick@10.1.1.30` |
| `BACKUP_LOCK_FILE` | Lock file path | `/var/lock/backup-data.lock` |
| `NO_COLOR` | Set to any value to disable color | (unset) |

### Exit codes

Standard CLIG conventions:

| Code | Meaning |
| --- | --- |
| `0` | All backups succeeded |
| `1` | One or more backups failed (or runtime error) |
| `2` | Bad invocation (unknown flag, conflicting options, etc.) |

### Examples

Watch a backup run interactively with progress on the terminal:

```bash
backup-data
```

Run from cron with output to log file only:

```bash
backup-data --quiet
```

Preview without changing anything (great for testing config changes):

```bash
backup-data --dry-run --verbose
```

Skip the remote backup (e.g., zorak is offline):

```bash
backup-data --no-remote
```

Sync to a different remote host:

```bash
backup-data --remote-host=backup@nas.local
```

Override defaults via environment for one run:

```bash
BACKUP_LOG_DIR=/tmp/backup-logs backup-data --verbose
```

---

## How it works

### rsync flags

```bash
rsync -ah --info=progress2,stats1   # normal mode
rsync -avh --info=progress2,stats2  # verbose mode
```

| Flag | Why |
| --- | --- |
| `-a` | Archive mode: recursive, preserves permissions, ownership, timestamps, symlinks |
| `-h` | Human-readable sizes (`1.2M` instead of `1234567`) |
| `-v` | Verbose file list (only in verbose mode) |
| `--info=progress2` | Single-line transfer progress (log-friendly, unlike `--progress`) |
| `--info=stats1` | Summary statistics at the end |
| `--dry-run` | Preview only (added by `-n` flag) |

**Note:** `-z` (compression) is deliberately omitted. On a gigabit LAN with already-compressed data (videos, photos, archives), compression hurts more than it helps — modern networks transfer faster than a CPU can compress. Add it back only over slow WAN links.

### Single-instance lock

The script uses `flock` on `/var/lock/backup-data.lock` to prevent overlapping runs. If a backup runs longer than expected and the next cron tick fires, the second invocation exits with code 2 instead of stomping on the first.

### Logging

Each run creates a timestamped log at `${BACKUP_LOG_DIR}/backup-data-YYYY-MM-DD-HHMMSS.log`. The script auto-prunes logs older than `${BACKUP_LOG_RETENTION_DAYS}` days at the end of every run.

When run interactively (stderr is a TTY), output goes to **both** the terminal and the log file via `tee`. When run from cron (no TTY), output goes only to the log file. Detection is automatic — no flag needed.

### Output destinations

Following CLIG conventions:

- **Status messages and errors** → stderr (and log file)
- **Data output** → stdout (this script doesn't produce machine-readable data, so stdout stays empty in normal use — pipe-safe)
- **Color** → only used when stderr is a terminal AND `NO_COLOR` is unset AND `TERM` isn't `dumb`

---

## Requirements

- **bash** 4+ (uses `mapfile`, arrays)
- **rsync** (any modern version)
- **flock** (from `util-linux`, present on basically every Linux)
- **find**, **date** (coreutils)
- **SSH key-based auth** to the remote host (no password prompts)

For the remote backup leg, set up passwordless SSH from brak to zorak:

```bash
# On brak, as the user that runs backup-data
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_backup -N ''
ssh-copy-id -i ~/.ssh/id_ed25519_backup mick@10.1.1.30

# Test
ssh mick@10.1.1.30 'echo OK'
```

If you're using a non-default key, add a stanza to `~/.ssh/config`:

```
Host 10.1.1.30 zorak
    User mick
    IdentityFile ~/.ssh/id_ed25519_backup
    IdentitiesOnly yes
```

---

## Troubleshooting

### "another instance is already running"

A previous backup is still running, or it crashed without releasing the lock. Check:

```bash
ps aux | grep backup-data
ls -la /var/lock/backup-data.lock
```

If no process is actually running, remove the stale lock:

```bash
sudo rm /var/lock/backup-data.lock
```

### Cron runs but the backup didn't happen

```bash
# Check cron actually fired
journalctl -u cron --since "today"          # or /var/log/syslog on older systems

# Check the latest log
ls -lt ~/logs/backup-data-*.log | head -1
tail -50 "$(ls -t ~/logs/backup-data-*.log | head -1)"
```

Common culprits:

- `PATH` too minimal in cron's environment — set `PATH` explicitly in the crontab
- `rsync` or `flock` not in cron's `PATH`
- Script not executable: `sudo chmod 755 /usr/local/bin/backup-data`
- Wrong user — cron runs as the user defined in the cron file, and that user must have SSH access to zorak and write access to local destinations

### SSH prompts for a password from cron

Cron has no SSH agent. Either set up a passwordless SSH key, or use `~/.ssh/config` to point at a specific key file. See **Requirements** above.

### Remote backup fails with "Permission denied"

The remote user needs write access to `/data-1` and `/data-2` on zorak:

```bash
ssh mick@10.1.1.30 'ls -ld /data-1 /data-2'
```

### "rsync: connection unexpectedly closed"

Usually a network blip or the remote host going down mid-transfer. rsync is restartable — the next run will pick up where it left off.

---

## Design notes

- Designed to be both **cron-safe** (machine-friendly output to a log file) and **interactive-friendly** (TTY detection, color, progress) without separate code paths.
- All script output respects [CLIG](https://clig.dev) conventions: stderr for messaging, stdout for data, exit codes that mean something, helpful errors with hints.
- No dependencies beyond what ships in a default Ubuntu install. No Python, no Go binary, no config file format to learn — just bash, rsync, and flock.
- Configuration via flags AND environment variables, so it works equally well from cron, systemd units, or a shell prompt.

---

## Roadmap / ideas

- [ ] Reverse direction: pull backup from brak → zorak (in case brak's HBA dies)
- [ ] Email or webhook notifications on failure (currently just exit codes + log file)
- [ ] Optional `--checksum` mode for monthly deep verification
- [ ] systemd timer alternative to cron (better logging, cleaner failure semantics)
- [ ] Pre-flight check that verifies ZFS pool health before running

---

## License

[MIT](./LICENSE) — do whatever you want, no warranty.
