# Captain Cronos Command Reference

Generated: Mon Jul  6 03:07:43 EDT 2026

## cc about

~~~text
Usage:
  cc about

Shows toolkit overview, major components, and documentation locations.
~~~

## cc asset

~~~text
Usage:
  cc asset init
  cc asset list [TYPE]
  cc asset show TYPE NAME
  cc asset path [TYPE]
  cc asset search TYPE QUERY
  cc asset inventory TYPE
  cc asset create TYPE NAME [key=value ...]
  cc asset set TYPE NAME key=value [key=value ...]
  cc asset state TYPE NAME STATE [NOTE]
  cc asset history TYPE NAME
  cc asset retire TYPE NAME [NOTE]
  cc asset export [TYPE]

Types:
  drives
  systems
  repositories
  licenses
  purchases

Lifecycle states:
  new inventory testing qualified production watch failed retired
~~~

## cc audit

~~~text
Usage:
  cc audit [summary|commands] [--strict]
  cc audit fix [--apply]

Runs consistency checks across tools/commands.

Default checks:
  - Bash syntax
  - Script header
  - Version header
  - Repository header
  - Purpose header
  - --help support
  - --version support

Strict checks add:
  - executable bit
  - Category header
  - Requires header

Fix mode:
  - Adds executable bit to tools/commands/*
  - Adds missing Category and Requires headers for known commands
  - Dry-run by default unless --apply is supplied

Notes:
  Most toolkit commands are dispatched by cc and do not require executable bits
  during normal operation, but repository command files should be executable for
  packaging and strict audit compliance.
~~~

## cc baseline

~~~text
Usage: cc baseline

Captures operating-system baseline shell files.
~~~

## cc capability

~~~text
Usage:
  cc capability [list|check NAME]

Examples:
  cc capability
  cc capability list
  cc capability check smart
  cc capability check zfs
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

## cc deps

~~~text
Usage:
  cc deps [summary]
  cc deps command COMMAND
  cc deps core
  cc deps docs
  cc deps storage
  cc deps optional

Shows dependency status for toolkit commands and dependency groups.
~~~

## cc dev-update

~~~text
Usage:
  cc dev-update [all|npm|pipx|pip|cargo|go|gem] [--dry-run|--apply]
  cc dev-update [all|npm|pipx|pip|cargo|go|gem] --status-only
  cc update dev [--dry-run|--apply]
  cc update npm [--dry-run|--apply]

Default:
  cc dev-update runs in --dry-run mode.

Behavior:
  - Detects npm, pipx, pip, cargo, go, and gem.
  - Reports installed/not installed status.
  - Reports whether mutating updates are enabled.
  - Reports the dry-run command for each manager.
  - Runs mutating updates only with --apply.

Notes:
  Developer package managers are not updated by cc system-update.
  npm global packages are never updated unless --apply is supplied.
  pip, cargo, go, and gem are report-only until a safer per-ecosystem policy exists.
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

## cc drive-burnin

~~~text
Usage:
  cc drive-burnin plan /dev/sdX
  cc drive-burnin start /dev/sdX
  cc drive-burnin status /dev/sdX

Phase 1 framework only.

Actions:
  plan    Show the intended drive acceptance workflow.
  start   Capture initial report and start non-destructive qualification.
  status  Show current SMART self-test status.
~~~

## cc drive-inventory

~~~text
Usage:
  cc drive-inventory [table|csv|markdown]

Shows attached block devices with model, serial, size, transport, mountpoints, and SMART basics.

This is read-only inventory output. It does not start SMART tests or modify disks.
~~~

## cc drive-qualify

~~~text
Usage:
  cc drive-qualify start [--long] /dev/sdX
  cc drive-qualify status /dev/sdX
  cc drive-qualify complete /dev/sdX
  cc drive-qualify /dev/sdX

Actions:
  start     Capture pre-test report, start short SMART self-test, and optionally start long self-test.
  status    Show SMART self-test status.
  complete  Capture final report and mark asset qualified when SMART result is GOOD.

Options:
  --long    Start a SMART long self-test after the initial report instead of only a short self-test.

Notes:
  This is non-destructive. It does not run write/read burn-in.
~~~

## cc drive-report

~~~text
Usage:
  cc drive-report /dev/sdX
  cc drive-report /dev/nvme0n1

Creates an archived drive report under the host report directory.
Also creates/updates a drive asset record and appends asset history.
~~~

## cc drive-smart

~~~text
Usage:
  cc drive-smart /dev/sdX
  cc drive-smart /dev/nvme0n1

Shows a concise SMART health summary for one drive.
~~~

## cc drive-test

~~~text
Usage:
  cc drive-test status /dev/sdX
  cc drive-test short  /dev/sdX
  cc drive-test long   /dev/sdX
  cc drive-test abort  /dev/sdX

Actions:
  status   Show SMART self-test status and recent self-test log.
  short    Start SMART short self-test.
  long     Start SMART long self-test.
  abort    Abort handling remains in the command wrapper for compatibility.

Notes:
  Starting tests may require sudo.
  This command does not run destructive write/read burn-in tests.
~~~

## cc drives

~~~text
Usage: cc drives

Shows physical block devices, filesystems, labels, UUIDs, usage, and mount points.
~~~

## cc env

~~~text
Usage:
  cc env [summary]
  cc env path [--fix|--apply]
  cc env shell
  cc env host
  cc env doctor [--fix|--apply]

Environment namespace for host identity, shell files, and PATH health.

PATH policy:
  PASS  required path is present exactly once
  WARN  required path is duplicated or directory is missing
  FAIL  required path is absent from PATH

Fix/apply behavior:
  - creates required directories when missing
  - appends guarded PATH entries to ~/.bashrc when missing
  - removes duplicate PATH entries in the current output guidance
  - preserves first occurrence order when showing the cleaned PATH
~~~

## cc framework

~~~text
Usage:
  cc framework [status|checklist|verify]

Actions:
  status     Show framework milestone progress.
  checklist  Print the 1.3 framework completion checklist.
  verify     Run the 1.3 framework quality gates.
~~~

## cc gitflow

~~~text
Usage:
  cc gitflow [repo-directory]

Launches the interactive Captain Cronos Git assistant.

Examples:
  cc gitflow
  cc gitflow ~/GitHub/CaptainCronos-01-ShellToolkit
~~~

## cc helpme-refresh

~~~text
Usage:
  cc helpme-refresh [--apply]

Replaces the installed helpme function with canonical Captain Cronos framework help.
Default is dry-run.
~~~

## cc init

~~~text
Usage:
  cc init [--apply] [--host-id ID] [--role ROLE] [--profile PROFILE]
  cc init --interactive [--apply]

Initializes a portable Captain Cronos host identity.

Roles:
  developer   Development workstation
  workbench   Live USB / drive qualification bench
  server      General Linux server
  nas         NAS appliance or NAS-adjacent host
  laptop      Mobile workstation

Profiles:
  developer
  workbench
  server
  truenas-scale
  laptop
  default

Default is dry-run.
~~~

## cc install

~~~text
Usage:
  cc install [--dry-run] [--force]

Installs or updates the active Shell Toolkit launcher at:
  ~/bin/cc

Options:
  --dry-run    Show what would be installed without changing files.
  --force      Reinstall even when ~/bin/cc already matches the source.
  --help, -h   Show this help.
  --version    Show command and toolkit version.

Notes:
  This command installs only the cc launcher. The full shell-file installer
  remains available as install/install.sh.
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

## cc platform

~~~text
Usage:
  cc platform [summary|capabilities]

Shows detected platform, package manager, init system, host identity, and capabilities.
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

## cc prompt

~~~text
Usage:
  cc prompt
  cc prompt TEMPLATE

Dynamic Prompt Engine:
  Discovers templates from templates/prompts/.
  Run without TEMPLATE to choose from the interactive template menu.
  TEMPLATE may be a template id or template title.

Navigation:
  previous  Go back one question.
  next      Keep the current answer and continue.
  edit      Clear and re-enter the current answer.
  cancel    Exit without rendering.

After preview:
  [Y]es     Generate, copy when supported, and print the rendered prompt.
  [E]dit    Edit a collected answer and preview again.
  [C]ancel  Exit without generating.
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
  cc repos [list|status|health|inventory|fetch|pull|sync|backup|commit|push|publish|verify|doctor] [options]

Options:
  --root PATH      Repository root. Default: ~/GitHub
  --out FILE       Output file for inventory. Supports .md and .csv
  --bundle-dir DIR Bundle output directory. Default: ~/.captaincronos/repo-bundles
  --message TEXT   Commit message for commit actions.
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
  commit     Commit dirty repositories with --message. Dry-run by default.
  push       Push clean repositories ahead of origin. Dry-run by default.
  publish    Push clean main branches with git push origin main. Dry-run by default.
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
  cc repos commit --message "work in progress"
  cc repos push --apply
  cc repos publish --apply
~~~

## cc roadmap

~~~text
Usage:
  cc roadmap [markdown]

Shows the project roadmap from docs/ROADMAP.md.
~~~

## cc selftest

~~~text
Usage:
  cc selftest [--verbose] [--json]

Runs the toolkit engineering self-test suite.

Checks:
  - shared library syntax and load checks
  - prompt engine template validation
  - strict command audit
  - documentation lint
  - release check
  - registry load
  - about command load
  - roadmap command load
  - plugin status load

Options:
  --verbose  Show full command output.
  --json     Emit simple JSON summary.
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

## cc storage

~~~text
Usage:
  cc storage <action> [options]

Actions:
  inventory        Show physical drive inventory.
  drives           Show mounted and installed storage devices.
  smart DEVICE     Show concise SMART summary for one device.
  test DEVICE ...  Start or inspect SMART self-tests.
  report DEVICE    Save SMART report and update drive asset records.
  qualify DEVICE   Run non-destructive drive qualification workflow.
  burnin DEVICE    Run or inspect drive burn-in workflow framework.
  workbench        Prepare or inspect live USB workbench environment.
  deps             Show storage dependency status.
  status           Show storage workbench-oriented status summary.

Compatibility:
  Existing commands remain available:
    cc drive-inventory
    cc drives
    cc drive-smart
    cc drive-test
    cc drive-report
    cc drive-qualify
    cc drive-burnin
    cc workbench

Examples:
  cc storage inventory
  cc storage smart /dev/sda
  cc storage test /dev/sda status
  cc storage test /dev/sda short
  cc storage test /dev/sda long
  cc storage report /dev/sda
  cc storage qualify /dev/sda
  cc storage workbench status
~~~

## cc system-update

~~~text
Usage: cc system-update [--dry-run]

Runs the managed system update workflow: apt/nala/aptitude, snap, flatpak, Firefox, Thunderbird, and GRUB CLI Safe Boot refresh.

Notes:
  Developer package managers are detected and reported, but not updated by system-update.
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
  cc update dev [all|npm|pipx|pip|cargo|go|gem] [--dry-run|--apply]
  cc update npm [--dry-run|--apply]

Default:
  cc update runs in --dry-run mode.

Workflow:
  1. toolkit-update       Pull latest toolkit changes and reinstall command files.
  2. system-update        Run managed OS/app update workflow.
  3. kernel-cleanup       Review obsolete kernels. Applies only with --apply.
  4. dev-update           Optional developer maintenance when explicitly enabled.
  5. verify               Verify repository structure and Bash syntax.
  6. doctor               Run toolkit health checks.
  7. drives / smart       Show storage inventory and SMART summary.
  8. status               Show repository status.

Notes:
  Use cc toolkit-update for the old direct toolkit pull/reinstall behavior.
  Use cc system-update for package/app updates only.
  Use cc update dev --dry-run before applying developer package updates.
  Set DEV_UPDATES=yes in cc config to include developer updates in cc update --apply.
  Use cc kernel-cleanup separately before trusting automated cleanup.
~~~

## cc verify

~~~text
Usage:
  cc verify [all]
  cc verify executable [--apply]

Actions:
  all         Run repository verification workflow.
  executable Check tools/commands executable permissions.

Options:
  --apply     Repair executable permissions for tools/commands/*.
~~~

## cc version

~~~text
Toolkit : 1.3.0-beta1
Codename: Blackbeard
Standard: 0.1.0
Baseline: ubuntu-26.04
Release : 2026-06-29
~~~

## cc workbench

~~~text
Usage:
  cc workbench [prepare|status] [--apply] [--host-id ID] [--repo URL] [--target DIR] [--no-selftest]

Prepares a live USB / temporary Linux environment for drive qualification.

Default is dry-run.

Examples:
  cc workbench
  cc workbench prepare --apply
  cc workbench prepare --apply --host-id drivebench
  cc workbench status
~~~
