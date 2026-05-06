# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-05-06

Major rewrite. The script is now production-grade and follows
[Command Line Interface Guidelines](https://clig.dev). Not backward-compatible
with the previous `backup_data_files.sh` invocation (script renamed, flags
introduced).

### Added
- New `backup-data` script (replaces `backup_data_files.sh`).
- Standard CLI flags: `--help`, `--version`, `--dry-run`, `--verbose`, `--quiet`,
  `--no-color`, `--no-local`, `--no-remote`, `--log-dir`, `--remote-host`.
- Short-form flags where appropriate (`-h`, `-V`, `-n`, `-v`, `-q`).
- Standard exit codes: 0 for success, 1 for runtime failure, 2 for bad
  invocation.
- TTY detection: output goes to terminal AND log file in interactive mode,
  log file only when run from cron.
- Color output with `NO_COLOR` environment variable support and automatic
  disable when stderr is not a terminal.
- Single-instance lock via `flock` on `/var/lock/backup-data.lock`. Prevents
  overlapping runs when a backup takes longer than the cron interval.
- Automatic log rotation. Logs older than 30 days are pruned at the end of
  each run. Configurable via `BACKUP_LOG_RETENTION_DAYS`.
- Configuration via environment variables: `BACKUP_LOG_DIR`,
  `BACKUP_LOG_RETENTION_DAYS`, `BACKUP_REMOTE_HOST`, `BACKUP_LOCK_FILE`.
- Per-job timing in log output.
- Pre-flight checks for required commands and source/destination directories.
- Continue-on-failure semantics: if one rsync fails, remaining jobs still run,
  and the script exits non-zero so cron can detect the failure.
- Comprehensive `README.md` documenting installation, usage, environment
  variables, exit codes, design rationale, troubleshooting, and SSH setup.

### Changed
- Removed `-z` (compression) from rsync flags. On a gigabit LAN with already-
  compressed media, compression hurts more than it helps.
- Replaced `--progress` with `--info=progress2,stats1`. The new flag produces
  log-friendly single-line summaries instead of carriage-return-based progress
  bars that smear into log files.
- Status messages now go to stderr (clig.dev convention). Stdout is reserved
  for data — the script produces none, so it's pipe-safe.
- All variables are quoted; safe with paths containing spaces.
- `set -u` and `set -o pipefail` for stricter error handling.

### Removed
- `backup_data_files.sh` — replaced by `backup-data`.
- `make_cron_job.sh` — was an unmodified template (referenced a different
  user and a non-existent cleanup script). Cron setup is now documented in
  the README; no helper script needed.

### Fixed
- Function names with hyphens (e.g., `remote_data-1_backup`) which were
  syntactically invalid in bash. Functions are now hyphen-free and iterate
  over a configurable `SOURCES` array.
- rsync stderr was previously discarded — now captured in the log file,
  so errors are actually visible.
- Per-job timing is now reliably captured in the log (was previously sent
  to terminal stderr only).
- Script exit code now reflects the worst exit code across all jobs. Cron
  can now actually detect backup failures.

## [1.0] - 2023 (approximate)

Initial public version. Functional but rough.

### Added
- `backup_data_files.sh` — bash script using rsync to back up `/data-1` and
  `/data-2` to local `/data-3` and to a remote host (zorak).
- `make_cron_job.sh` — cron installer template (never customized for this
  project; non-functional as written).
- `LICENSE` — MIT.
- One-line `README.md`.

[2.0.0]: https://github.com/mickmill54/home_automation/releases/tag/v2.0.0
[1.0]: https://github.com/mickmill54/home_automation/commits/main
