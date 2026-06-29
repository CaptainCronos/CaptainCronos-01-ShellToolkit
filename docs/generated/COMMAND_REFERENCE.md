# Captain Cronos Command Reference

Generated: Mon Jun 29 06:58:00 PM EDT 2026

## cc baseline

~~~text
Usage: cc baseline

Captures operating-system baseline shell files.
~~~

## cc config

~~~text
Usage:
  cc config show
  cc config init
  cc config get KEY [DEFAULT]
  cc config set KEY VALUE

Configuration file:
  ~/.captaincronos/config
~~~

## cc defaults

~~~text
Usage: cc defaults

Promotes active shell files into defaults/v1.
~~~

## cc docs

~~~text
Usage:
  cc docs [build|inventory|reference|changelog|lint] [--apply] [--out DIR]

Actions:
  inventory  Generate command inventory.
  reference  Generate command reference from command help output.
  changelog  Generate recent Git history summary.
  lint       Check command headers and Bash syntax.
  build      Generate all documentation outputs.

Options:
  --apply    Write generated files under docs/generated.
  --out DIR  Override output directory.
~~~

## cc doctor

~~~text
Usage: cc doctor [--full]

Runs repository, command syntax, installation, and basic host health checks.
Use --full to include storage inventory and SMART summary.
~~~

## cc drives

~~~text
Usage: cc drives

Shows physical block devices, filesystems, labels, UUIDs, usage, and mount points.
~~~

## cc gitflow

~~~text
~~~

## cc helpme-refresh

~~~text
Usage: cc helpme-refresh [--apply]

Patches ~/.bash_functions so helpme lists the new cc command architecture.
Default is dry-run.
~~~

## cc install

~~~text
Captain Cronos Shell Toolkit Installer
======================================

Usage:
  install/install.sh [options]

Options:
  --dry-run          Show what would be done without copying files.
  --no-backup        Do not create timestamped backups before installing.
  --no-baseline      Do not create baseline files if baseline appears empty.
  --no-bashrc        Install aliases/functions only; do not replace ~/.bashrc.
  --no-commands      Do not install command front-end into ~/bin.
  --help, -h         Show this help.
  --version          Show installer and toolkit version.

What it does:
  1. Loads VERSION from the repository.
  2. Verifies required repository files.
  3. Verifies Bash syntax.
  4. Optionally captures baseline OS shell files.
  5. Backs up current ~/.bashrc, ~/.bash_aliases, and ~/.bash_functions.
  6. Installs bash/bashrc, bash/bash_aliases, and bash/bash_functions.
  7. Installs the cc command front-end into ~/bin.
  8. Verifies installed files.
  9. Prints a final install report.
~~~

## cc kernel-cleanup

~~~text
Usage: cc kernel-cleanup [--dry-run|--apply]

Safely reviews obsolete kernel packages. Default is --dry-run.
Keeps the running kernel and the newest 2 additional installed kernels.

Environment: KEEP_COUNT=3 cc kernel-cleanup --dry-run
~~~

## cc monthly-health

~~~text
Usage:
  cc monthly-health [--stdout] [--file]

Generates a host health and maintenance report.

Default output:
  ~/.captaincronos/reports/monthly-health/monthly-health-YYYYMMDD-HHMMSS.log

Environment:
  JOURNAL_SINCE="7 days ago" cc monthly-health
  TOP_N=10 cc monthly-health --stdout
~~~

## cc monthly-health-timer

~~~text
Usage: cc monthly-health-timer status|retire|run-once|install-standalone|enable|disable

Recommended architecture: run cc monthly-health from the existing daily-backup-report framework.
The standalone user timer is retained only as an optional fallback.
~~~

## cc plugin

~~~text
Usage:
  cc plugin [list|status|info NAME]

Actions:
  list        List plugin directories.
  status      Show plugin directory status and file counts.
  info NAME   Show detail for one plugin directory.

This command only inspects plugin directories. It does not enable, disable, or execute plugins yet.
~~~

## cc registry

~~~text
Usage:
  cc registry [table|tsv|markdown]

Shows the command metadata registry generated from tools/commands headers.
~~~

## cc release

~~~text
Usage:
  cc release [plan|check] [--apply]

Actions:
  plan   Show the release workflow checklist.
  check  Run pre-release verification checks.

This is the first release-engine stage. Version bumping, tagging, and push automation are intentionally not automatic yet.
~~~

## cc repo

~~~text
Usage: cc repo

Shows the repository path, current branch, and origin remote.
~~~

## cc repos

~~~text
Usage:
  cc repos [list|status|health|inventory|fetch|pull|sync|backup|verify|doctor] [options]

Options:
  --root PATH      Repository root. Default: ~/GitHub
  --out FILE       Output file for inventory. Supports .md and .csv
  --bundle-dir DIR Bundle output directory. Default: ~/.captaincronos/repo-bundles
  --apply          Apply mutating actions. Default is dry-run.

Actions:
  list       List detected Git repositories.
  status     Show repository dashboard with health, branch, state, sync, type, and origin.
  health     Show health-only dashboard and summary.
  inventory  Generate repository inventory table. Use --out to save.
  fetch      Fetch all remotes and prune stale refs. Dry-run by default.
  pull       Pull --ff-only for clean repositories. Dry-run by default.
  sync       Fetch then pull --ff-only for clean repositories. Dry-run by default.
  backup     Create git bundle backups for clean repositories. Dry-run by default.
  verify     Run cc verify for toolkit repositories that contain tools/cc.
  doctor     Run cc doctor for toolkit repositories that contain tools/cc.

Examples:
  cc repos status
  cc repos health
  cc repos inventory --out ~/repo-inventory.md
  cc repos inventory --out ~/repo-inventory.csv
  cc repos fetch --apply
  cc repos sync --apply
  cc repos backup --apply
~~~

## cc smart

~~~text
Usage: cc smart [device] [--full] [--logs]

Examples:
  cc smart
  cc smart sdd
  cc smart sdd --full
  cc smart sdd --logs
~~~

## cc status

~~~text
Usage: cc status

Shows branch, origin, recent commits, and working tree status.
~~~

## cc system-update

~~~text
Usage: cc system-update [--dry-run]

Runs the managed system update workflow: apt/nala/aptitude, snap, flatpak, Python venv, Firefox, Thunderbird, and GRUB CLI Safe Boot refresh.

Notes:
  This command does not purge old kernels. Review kernel cleanup separately after this workflow is stable.
~~~

## cc toolkit-update

~~~text
Usage: cc toolkit-update [install/update.sh options]

Pulls latest toolkit changes and runs the toolkit update workflow.
~~~

## cc update

~~~text
Usage:
  cc update [--dry-run|--apply] [--toolkit-only|--system-only|--health-only]

Default:
  cc update runs in --dry-run mode.

Workflow:
  1. toolkit-update       Pull latest toolkit changes and reinstall command files.
  2. system-update        Run managed OS/app update workflow.
  3. kernel-cleanup       Review obsolete kernels. Applies only with --apply.
  4. verify               Verify repository structure and Bash syntax.
  5. doctor               Run toolkit health checks.
  6. drives / smart       Show storage inventory and SMART summary.
  7. status               Show repository status.

Notes:
  Use cc toolkit-update for the old direct toolkit pull/reinstall behavior.
  Use cc system-update for package/app updates only.
  Use cc kernel-cleanup separately before trusting automated cleanup.
~~~

## cc verify

~~~text
Usage: cc verify

Runs the repository verification workflow.
~~~

## cc version

~~~text
Toolkit : 1.2.0-alpha1
Codename: Blackbeard
Standard: 0.1.0
Baseline: ubuntu-26.04
Release : 2026-06-29
~~~

