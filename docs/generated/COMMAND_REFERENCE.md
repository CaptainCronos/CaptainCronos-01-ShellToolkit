# Captain Cronos Command Reference

Toolkit version: 1.3.0-beta2 (Blackbeard)

## cc about

~~~text
Usage:
  cc about

Shows toolkit overview, major components, and documentation locations.
~~~

### Switch discovery

~~~text
Command: cc about

Usage:
  cc about

Show toolkit overview, components, and documentation locations.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
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

### Switch discovery

~~~text
Command: cc asset

Usage:
  cc asset <subcommand> [arguments]

Manage local lifecycle asset inventory records.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  init............. Initialize asset directories.
  list............. List assets, optionally by type.
  show............. Show one asset record.
  path............. Show an asset directory path.
  search........... Search asset records by type and query.
  inventory........ Show an inventory for one asset type.
  create........... Create an asset record from key=value fields.
  set.............. Update fields on an existing asset record.
  state............ Change lifecycle state and optionally record a note.
  history.......... Show one asset's lifecycle history.
  retire........... Retire an asset and optionally record a note.
  export........... Export assets, optionally by type.

Discovery:
  cc asset <subcommand> switches
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

### Switch discovery

~~~text
Command: cc audit

Usage:
  cc audit [summary

commands] [switches]; cc audit fix [switches]

Switches:
  --strict.......... Require executable bits plus Category and Requires headers.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  summary......... Show the default command audit summary.
  commands........ Show per-command audit detail.
  fix............. Preview or apply managed audit repairs.

Discovery:
  cc audit <subcommand> switches
~~~

## cc baseline

~~~text
Usage: cc baseline

Captures operating-system baseline shell files.
~~~

### Switch discovery

~~~text
Command: cc baseline

Usage:
  cc baseline

Capture operating-system baseline shell files.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
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

### Switch discovery

~~~text
Command: cc capability

Usage:
  cc capability [list

check NAME]

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  list......... List platform capabilities.
  check........ Check one named capability.

Discovery:
  cc capability <subcommand> switches
~~~

## cc config

~~~text
Usage:
  cc config show
  cc config status
  cc config validate
  cc config init
  cc config get KEY [DEFAULT]
  cc config set KEY VALUE
  cc config migrate [--apply]

Configuration file:
  Global: ~/.captaincronos/config
  Host:   ~/.captaincronos/hosts/<host-id>/config

Host identity precedence:
  CC_HOST_ID runtime/test override -> stored host-id -> legacy global HOST_ID
  -> hostname fallback. An inherited CC_HOST_ID intentionally selects another
  host tree; unset it to use the stored identity. Status/validate report it.

Mutation safety:
  set and init use private atomic writes. Migration is preview-only unless
  --apply is supplied and creates a private backup before replacement.
~~~

### Switch discovery

~~~text
Command: cc config

Usage:
  cc config <subcommand> [arguments]

Read or update toolkit configuration.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  show............ Show redacted configuration layers and their sources.
  status.......... Show configuration ownership, schema, identity, and health.
  validate........ Validate configuration without writing.
  init............ Initialize missing global configuration and stable identity.
  get............. Read one key with an optional default.
  set............. Atomically set one global user configuration key.
  migrate......... Preview or explicitly apply the supported schema migration.

Discovery:
  cc config <subcommand> switches
~~~

## cc defaults

~~~text
Usage: cc defaults

Promotes active shell files into defaults/v1.
~~~

### Switch discovery

~~~text
Command: cc defaults

Usage:
  cc defaults

Promote active shell files into defaults/v1.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
~~~

## cc deps

~~~text
Usage:
  cc deps [summary]
  cc deps command COMMAND
  cc deps core
  cc deps docs
  cc deps storage
  cc deps kernel
  cc deps optional

Shows dependency status for toolkit commands and dependency groups.
~~~

### Switch discovery

~~~text
Command: cc deps

Usage:
  cc deps [subcommand] [arguments]

Show dependency status by command or profile.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  summary......... Show the default dependency summary.
  command......... Show dependencies for one registered command.
  core............ Show core dependencies.
  docs............ Show documentation dependencies.
  storage......... Show storage dependencies.
  kernel.......... Show kernel dependencies and optional capabilities.
  optional........ Show optional dependencies.

Discovery:
  cc deps <subcommand> switches
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

### Switch discovery

~~~text
Command: cc dev-update

Usage:
  cc dev-update [TARGET] [switches]

Review or apply supported developer package-manager updates.

Switches:
  --dry-run............ Report supported update operations without mutation. [default]
  --apply.............. Authorize only the developer ecosystem updates implemented as mutable.
  --status-only........ Report manager availability and policy without running update commands.
  --help, -h........... Show contextual command help.
  --version............ Show toolkit version information.
~~~

## cc docs

~~~text
Usage:
  cc docs [build|inventory|reference|changelog|lint|check] [--apply] [--out DIR]

Actions:
  inventory  Generate command inventory.
  reference  Generate command reference from command help output.
  changelog  Generate recent Git history summary.
  lint       Check command headers and Bash syntax.
  build      Generate all documentation outputs.
  check      Verify committed generated documents are current; never writes them.

Options:
  --apply    Write generated files under docs/generated.
  --out DIR  Override output directory.
~~~

### Switch discovery

~~~text
Command: cc docs

Usage:
  cc docs [subcommand] [switches]

Generate, lint, or verify toolkit documentation.

Switches:
  --apply........... Write generated files; omission prints output without updating generated files.
  --out DIR......... Use DIR instead of docs/generated as the output destination.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  build............ Generate every managed documentation output.
  inventory........ Generate the command inventory.
  reference........ Generate the command reference including switch contracts.
  changelog........ Generate the recent change summary.
  lint............. Check command headers and Bash syntax.
  check............ Verify generated documents are current; always read-only.

Discovery:
  cc docs <subcommand> switches
~~~

## cc doctor

~~~text
Usage: cc doctor [--full]

Runs repository, installation, semantic kernel, and basic host health checks.
Use --full to include storage inventory and SMART summary.
~~~

### Switch discovery

~~~text
Command: cc doctor

Usage:
  cc doctor [switches]

Run repository, installation, kernel, and host health checks.

Switches:
  --full............ Include storage inventory and SMART summary in diagnostics.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
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

### Switch discovery

~~~text
Command: cc drive-burnin

Usage:
  cc drive-burnin [subcommand] DEVICE

Run the non-destructive drive burn-in workflow framework.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  plan.......... Show the intended acceptance workflow.
  start......... Capture a report and begin non-destructive qualification.
  status........ Show current SMART self-test status.

Discovery:
  cc drive-burnin <subcommand> switches
~~~

## cc drive-inventory

~~~text
Usage:
  cc drive-inventory [table|csv|markdown]

Shows attached block devices with model, serial, size, transport, mountpoints, and SMART basics.

This is read-only inventory output. It does not start SMART tests or modify disks.
~~~

### Switch discovery

~~~text
Command: cc drive-inventory

Usage:
  cc drive-inventory [table

csv

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  table........... Render the default table format.
  csv............. Render CSV inventory.
  markdown........ Render Markdown inventory.

Discovery:
  cc drive-inventory <subcommand> switches
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

### Switch discovery

~~~text
Command: cc drive-qualify

Usage:
  cc drive-qualify [subcommand] [switches] DEVICE

Run non-destructive drive qualification.

Switches:
  --long............ Start a SMART long self-test after the initial report instead of a short test.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  start........... Capture pre-test state and start SMART qualification.
  status.......... Show SMART qualification status.
  complete........ Capture final state and qualify a healthy asset.

Discovery:
  cc drive-qualify <subcommand> switches
~~~

## cc drive-report

~~~text
Usage:
  cc drive-report /dev/sdX
  cc drive-report /dev/nvme0n1

Creates an archived drive report under the host report directory.
Also creates/updates a drive asset record and appends asset history.
~~~

### Switch discovery

~~~text
Command: cc drive-report

Usage:
  cc drive-report DEVICE

Archive a drive report and update its asset record.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
~~~

## cc drive-smart

~~~text
Usage:
  cc drive-smart /dev/sdX
  cc drive-smart /dev/nvme0n1

Shows a concise SMART health summary for one drive.
~~~

### Switch discovery

~~~text
Command: cc drive-smart

Usage:
  cc drive-smart DEVICE

Show a concise SMART health summary.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
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

### Switch discovery

~~~text
Command: cc drive-test

Usage:
  cc drive-test <subcommand> DEVICE

Start or inspect SMART self-tests.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  status........ Show SMART self-test status and recent log.
  short......... Start a SMART short self-test.
  long.......... Start a SMART long self-test.
  abort......... Use the retained compatibility abort handler.

Discovery:
  cc drive-test <subcommand> switches
~~~

## cc drives

~~~text
Usage: cc drives

Shows physical block devices, filesystems, labels, UUIDs, usage, and mount points.
~~~

### Switch discovery

~~~text
Command: cc drives

Usage:
  cc drives

Show physical devices, filesystems, labels, usage, and mounts.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
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
  - atomically installs one canonical managed PATH block in ~/.bashrc
  - removes exact known legacy Captain Cronos PATH lines and guards
  - preserves unknown PATH customization and unrelated file content
  - preserves first occurrence order when showing the cleaned PATH
  - cannot modify the already-running parent shell's PATH
~~~

### Switch discovery

~~~text
Command: cc env

Usage:
  cc env [subcommand] [switches]

Inspect or repair host identity, shell files, and PATH health.

Switches:
  --fix, --apply........ Repair managed PATH startup configuration; inspection is the default.
  --help, -h............ Show contextual command help.
  --version............. Show toolkit version information.

Subcommands:
  summary........ Show the environment summary.
  path........... Inspect or repair managed PATH state.
  shell.......... Inspect managed shell-file state.
  host........... Show resolved host identity.
  doctor......... Run environment diagnostics and optionally repair PATH.

Discovery:
  cc env <subcommand> switches
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

### Switch discovery

~~~text
Command: cc framework

Usage:
  cc framework [subcommand]

Inspect or verify framework milestone status.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  status........... Show framework milestone progress.
  checklist........ Print the 1.3 completion checklist.
  verify........... Run framework quality gates.

Discovery:
  cc framework <subcommand> switches
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

### Switch discovery

~~~text
Command: cc gitflow

Usage:
  cc gitflow [REPOSITORY]

Launch the interactive Captain Cronos Git assistant.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
~~~

## cc helpme-refresh

~~~text
Usage:
  cc helpme-refresh [--apply]

Replaces the installed helpme function with canonical Captain Cronos framework help.
Default is dry-run.
~~~

### Switch discovery

~~~text
Command: cc helpme-refresh

Usage:
  cc helpme-refresh [switches]

Preview or replace the installed helpme function.

Switches:
  --dry-run......... Preview replacement of the installed helpme function. [default]
  --apply........... Authorize replacement of the managed helpme function block.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
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

CC_HOST_ID is an explicit runtime/test override with precedence over the stored
identity. Prefer --host-id for initialization; an existing different stored
identity is never replaced implicitly.
~~~

### Switch discovery

~~~text
Command: cc init

Usage:
  cc init [switches]

Initialize a portable host identity, optionally interactively.

Switches:
  --apply.................. Authorize host identity and managed environment writes; omission is dry-run. [default: dry-run]
  --interactive............ Collect host identity choices interactively.
  --selftest............... Run the engineering selftest after initialization.
  --host-id ID............. Set the normalized Captain Cronos host identifier.
  --role ROLE.............. Select a supported host role.
  --profile PROFILE........ Select a supported platform profile.
  --help, -h............... Show contextual command help.
  --version................ Show toolkit version information.
~~~

## cc install

~~~text
Usage:
  cc install [--dry-run|--apply] [--force]

Installs or updates the active Shell Toolkit launcher at:
  ~/bin/cc

Options:
  --dry-run    Show what would be installed without changing files.
  --apply      Install or update the launcher.
  --force      Reinstall even when ~/bin/cc already matches the source.
  --help, -h   Show this help.
  --version    Show command and toolkit version.

Notes:
  Dry-run is the default. Launcher mutation requires --apply.
  This command installs only the cc launcher. The full shell-file installer
  remains available as install/install.sh --apply.
~~~

### Switch discovery

~~~text
Command: cc install

Usage:
  cc install [switches]

Install or update only the active cc launcher.

Switches:
  --dry-run......... Preview launcher installation without changing files. [default]
  --apply........... Explicitly authorize launcher installation or update.
  --force........... Reinstall the launcher even when the installed copy already matches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
~~~

## cc kernel

~~~text
Usage:
  cc kernel [help]
  cc kernel status
  cc kernel list
  cc kernel running
  cc kernel platform
  cc kernel artifacts
  cc kernel health
  cc kernel cleanup [--dry-run|--apply]
  cc kernel deps

Actions:
  status   Show kernel state plus distinct /boot, backing filesystem, and EFI usage.
  list     List installed sets with role, protection, APT-mark, and mapping states.
  running  Show the running release and matching installed packages.
  platform  Show detected kernel environment and Captain Cronos support.
  artifacts  Correlate packages with kernel, initramfs, map, and config artifacts.
  health   Evaluate kernel/package/artifact consistency without changing the host.
  cleanup  Review obsolete kernel packages; defaults to --dry-run.
  deps     Show required and optional kernel-management capabilities.

Safety:
  Cleanup protects the running kernel, a verified nearest-older fallback, a
  verified newest pending kernel, and KEEP_COUNT newest additional installed
  sets (default: 2). Only verified package/artifact mappings are candidates.
  Package removal requires an explicit --apply.

Compatibility:
  cc kernel-cleanup [--dry-run|--apply] remains available.

Examples:
  cc kernel status
  cc kernel platform
  cc kernel artifacts
  cc kernel health
  KEEP_COUNT=3 cc kernel list
  cc kernel cleanup --dry-run
~~~

### Switch discovery

~~~text
Command: cc kernel

Usage:
  cc kernel <subcommand> [switches]

Inspect kernel state, artifacts, health, dependencies, and cleanup candidates.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  status.............. Show kernel state and boot filesystem usage.
  help................ Show kernel namespace help.
  list................ List installed kernels and protection state.
  running............. Show the running release and matching packages.
  platform............ Show kernel platform support.
  capabilities........ Alias for platform.
  artifacts........... Correlate packages and boot artifacts.
  health.............. Evaluate package and artifact consistency read-only.
  cleanup............. Preview or apply protected obsolete-kernel cleanup.
  deps................ Show kernel-management dependencies.
  dependencies........ Alias for deps.

Discovery:
  cc kernel <subcommand> switches
~~~

## cc kernel-cleanup

~~~text
Usage: cc kernel-cleanup [--dry-run|--apply]

Compatibility entry point for `cc kernel cleanup`.
Defaults to --dry-run and delegates to the same running, fallback, pending,
KEEP_COUNT, and verified-mapping protections as `cc kernel cleanup`.

Environment: KEEP_COUNT=3 cc kernel-cleanup --dry-run
~~~

### Switch discovery

~~~text
Command: cc kernel-cleanup

Usage:
  cc kernel-cleanup [switches]

Compatibility entry point for cc kernel cleanup.

Switches:
  --dry-run......... Preview obsolete-kernel package removal without mutation. [default]
  --apply........... Delegate explicit removal authorization to cc kernel cleanup.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
~~~

## cc maintenance

~~~text
Usage:
  cc maintenance [status|inventory|retention|cleanup] [--format table|tsv] [--dry-run]

Inspects persistent files created or managed by ShellToolkit. It never follows
symlinks and never scans outside deterministic toolkit roots and exact legacy
producer paths.

Actions:
  status     Show retained totals and whether any cleanup policy is enabled.
  inventory  Show subsystem, class, location, accounting, policy, and ownership.
  retention  Explain lifecycle classes, ownership rules, and decision gates.
  cleanup    Preview retention cleanup policy. Cleanup is disabled in v1.3.

Options:
  --format FORMAT  Render inventory as table or stable TSV. [default: table]
  --dry-run        Explicit read-only cleanup preview; equivalent to cleanup.

Safety:
  No action deletes files. --apply is intentionally unavailable because no
  persistent resource class passed every deletion decision gate.
~~~

### Switch discovery

~~~text
Command: cc maintenance

Usage:
  cc maintenance [subcommand] [switches]

Inspect persistent toolkit resource ownership and retention.

Switches:
  --format FORMAT........ Render inventory as a readable table or stable TSV. [default: table]
  --dry-run.............. Show the disabled cleanup plan without mutation.
  --help, -h............. Show contextual command help.
  --version.............. Show toolkit version information.

Subcommands:
  status........... Summarize persistent resource accounting and cleanup state.
  inventory........ Inventory persistent resources by subsystem, class, policy, and root.
  retention........ Explain retention classes, ownership rules, and decision gates.
  cleanup.......... Preview the disabled cleanup policy; no apply interface exists.

Discovery:
  cc maintenance <subcommand> switches
~~~

## cc monthly-health

~~~text
Usage:
  cc monthly-health [--stdout] [--file]

Generates a host health and maintenance report.
Kernel health, platform, boot storage, and maintenance fields come from the
shared semantic kernel snapshot; no kernel cleanup is performed.

Default output:
  CC_REPORT_DIR/monthly-health/monthly-health-YYYYMMDD-HHMMSS.log

Environment:
  JOURNAL_SINCE="7 days ago" cc monthly-health
  TOP_N=10 cc monthly-health --stdout
~~~

### Switch discovery

~~~text
Command: cc monthly-health

Usage:
  cc monthly-health [switches]

Generate a host health and maintenance report without kernel cleanup.

Switches:
  --stdout.......... Write the report to standard output instead of a report file.
  --file............ Write the report file under the configured report directory. [default]
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
~~~

## cc monthly-health-timer

~~~text
Usage: cc monthly-health-timer status|retire|run-once|install-standalone|enable|disable

Recommended architecture: run cc monthly-health from the existing daily-backup-report framework.
The standalone user timer is retained only as an optional fallback.
~~~

### Switch discovery

~~~text
Command: cc monthly-health-timer

Usage:
  cc monthly-health-timer <subcommand>

Manage the optional user-scoped monthly-health timer.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  status.................... Show optional user timer state.
  retire.................... Retire the standalone timer configuration.
  run-once.................. Run monthly health once.
  install-standalone........ Install the optional standalone user timer.
  enable.................... Enable the optional user timer.
  disable................... Disable the optional user timer.

Discovery:
  cc monthly-health-timer <subcommand> switches
~~~

## cc platform

~~~text
Usage:
  cc platform [summary|capabilities]

Shows detected platform, package manager, init system, host identity, and capabilities.
~~~

### Switch discovery

~~~text
Command: cc platform

Usage:
  cc platform [summary

capabilities]

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  summary............. Show the platform summary.
  capabilities........ Show detected platform capabilities.

Discovery:
  cc platform <subcommand> switches
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

### Switch discovery

~~~text
Command: cc plugin

Usage:
  cc plugin [subcommand] [arguments]

Inspect plugin directories without executing plugins.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  list.......... List plugin directories.
  status........ Show plugin directory status and file counts.
  info.......... Show details for one plugin directory.

Discovery:
  cc plugin <subcommand> switches
~~~

## cc programs

~~~text
Usage:
  cc programs
  cc programs check
  cc programs show CAPABILITY

Read-only program interface reporting.

Examples:
  cc programs show pkg-manager
  cc programs show download
  cc programs show http-api
  cc programs show json
  cc programs show yaml
~~~

### Switch discovery

~~~text
Command: cc programs

Usage:
  cc programs [subcommand] [arguments]

Report configured semantic program interfaces.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  check........ Check required and optional program interfaces.
  show......... Show the implementation for one capability.

Discovery:
  cc programs <subcommand> switches
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
  previous  Move to the previous question.
  back      Move to the previous question.
  next      Keep the current answer and continue.
  help      Show help for the current menu or question.
  cancel    Exit without rendering.

After preview:
  1 Generate  Copy when supported and print the rendered prompt.
  2 Edit      Edit a collected answer and preview again.
  3 Cancel    Exit without generating.
~~~

### Switch discovery

~~~text
Command: cc prompt

Usage:
  cc prompt [TEMPLATE]

Run the interactive, metadata-discovered prompt engine.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
~~~

## cc registry

~~~text
Usage:
  cc registry [table|tsv|markdown]

Shows the command metadata registry generated from tools/commands headers.
~~~

### Switch discovery

~~~text
Command: cc registry

Usage:
  cc registry [table

tsv

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  table........... Render the metadata registry as a table.
  tsv............. Render tab-separated registry data.
  markdown........ Render the registry as Markdown.

Discovery:
  cc registry <subcommand> switches
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

### Switch discovery

~~~text
Command: cc release

Usage:
  cc release [subcommand] [switches]

Plan or check the release workflow.

Switches:
  --apply........... Accepted for workflow compatibility; release automation still does not bump, tag, or push.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  plan......... Show the release workflow checklist.
  check........ Run pre-release verification checks.

Discovery:
  cc release <subcommand> switches
~~~

## cc repo

~~~text
Usage: cc repo

Shows the repository path, current branch, and origin remote.
~~~

### Switch discovery

~~~text
Command: cc repo

Usage:
  cc repo

Show the current repository path, branch, and origin.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
~~~

## cc reports

~~~text
Usage:
  cc reports [status|list|prune] [--format table|tsv] [--apply]

Inspects deliberately retained Captain Cronos reports for the current host.
Inventory and preview are read-only. Only `reports prune --apply` deletes the
exact verified candidate plan displayed by that invocation.

Actions:
  status  Show report families, retained size, lifecycle defects, and candidates. [default]
  list    Show each recognized report and its retention state.
  prune   Preview the exact bounded deletion plan; creates no files or logs.

Options:
  --format FORMAT  Render list or prune as table or stable TSV. [default: table]
  --apply          Explicitly authorize the displayed prune plan.

Safety:
  Current-host scope only. Newest/minimum history, latest targets,
  qualification evidence, current operational logs, unknown material,
  configuration, identity, and assets are never report-prune candidates.
~~~

### Switch discovery

~~~text
Command: cc reports

Usage:
  cc reports [subcommand] [switches]

Inspect and conservatively prune persistent report history.

Switches:
  --format FORMAT........ Render list or prune as a readable table or stable TSV. [default: table]
  --help, -h............. Show contextual command help.
  --version.............. Show toolkit version information.

Subcommands:
  status........ Show current-host report lifecycle health and retained totals.
  list.......... List recognized retained reports and policy state.
  prune......... Preview or explicitly apply a bounded current-host report plan.

Discovery:
  cc reports <subcommand> switches
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

### Switch discovery

~~~text
Command: cc repos

Usage:
  cc repos [subcommand] [switches]

Inventory or conservatively manage local Git repositories.

Switches:
  --root PATH............. Inspect repositories below PATH. [default: ~/GitHub]
  --out FILE.............. Write inventory output to a .md or .csv file.
  --bundle-dir DIR........ Use DIR for bundle backups. [default: ~/.captaincronos/repo-bundles]
  --message TEXT.......... Set the commit message required by the commit subcommand; --message=TEXT is also accepted.
  --apply................. Authorize the selected mutating Git action; omission is dry-run. [default: dry-run]
  --help, -h.............. Show contextual command help.
  --version............... Show toolkit version information.

Subcommands:
  list............. List detected Git repositories.
  status........... Show the repository dashboard.
  health........... Show health-only dashboard and summary.
  inventory........ Generate a repository inventory.
  fetch............ Fetch and prune; dry-run by default.
  pull............. Pull fast-forward-only for clean repositories; dry-run by default.
  sync............. Fetch then fast-forward-only pull; dry-run by default.
  backup........... Create Git bundle backups; dry-run by default.
  commit........... Commit dirty repositories with a required message; dry-run by default.
  push............. Push eligible branches without force; dry-run by default.
  publish.......... Push eligible clean main branches; dry-run by default.
  verify........... Run cc verify in toolkit repositories.
  doctor........... Run cc doctor in toolkit repositories.

Discovery:
  cc repos <subcommand> switches
~~~

## cc roadmap

~~~text
Usage:
  cc roadmap [markdown]

Shows the canonical project roadmap from ROADMAP.md.
~~~

### Switch discovery

~~~text
Command: cc roadmap

Usage:
  cc roadmap [markdown]

Show the canonical project roadmap.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
~~~

## cc selftest

~~~text
Usage:
  cc selftest [--verbose] [--json] [--debug]

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
  --verbose  Show captured-output diagnostics without replaying successful stdout.
  --json     Emit simple JSON summary.
  --debug    Emit intentional diagnostic events to stderr.
~~~

### Switch discovery

~~~text
Command: cc selftest

Usage:
  cc selftest [switches]

Run the toolkit engineering self-test suite.

Switches:
  --verbose......... Show captured-output diagnostics without replaying successful stdout.
  --json............ Emit the selftest summary as JSON.
  --debug........... Emit intentional diagnostic events to standard error.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
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

### Switch discovery

~~~text
Command: cc smart

Usage:
  cc smart [DEVICE] [switches]

Show storage and SMART detail, optionally for one device.

Switches:
  --full............ Show full SMART device information for the selected device.
  --logs............ Show SMART log information for the selected device.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
~~~

## cc status

~~~text
Usage: cc status

Shows branch, origin, recent commits, and working tree status.
~~~

### Switch discovery

~~~text
Command: cc status

Usage:
  cc status

Show repository branch, origin, commits, and worktree status.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
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

### Switch discovery

~~~text
Command: cc storage

Usage:
  cc storage <subcommand> [arguments]

Route storage inventory, SMART, testing, reporting, and workbench operations.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  inventory........... Delegate to read-only drive inventory.
  help................ Show storage namespace help.
  drives.............. Delegate to mounted and installed device reporting.
  smart............... Delegate to concise SMART reporting.
  test................ Delegate to SMART self-test operations.
  report.............. Delegate to archived drive reporting.
  qualify............. Delegate to non-destructive qualification.
  burnin.............. Delegate to the burn-in workflow framework.
  burn-in............. Alias for burnin.
  workbench........... Delegate to workbench inspection or preparation.
  deps................ Show storage dependency status.
  dependencies........ Alias for deps.
  status.............. Show workbench-oriented storage status.

Discovery:
  cc storage <subcommand> switches
~~~

## cc system-update

~~~text
Usage: cc system-update [--dry-run|--apply]

Safely previews or applies platform package, Snap, and Flatpak updates.

Default:
  Dry-run. Persistent mutation requires explicit --apply.

Notes:
  Developer package managers are detected and reported, but not updated by system-update.
  Automatic Firefox/Thunderbird archive replacement is deferred for v1.3 RC.
  CLI Safe Boot/GRUB mutation is not part of routine system updates.
  This command does not purge old kernels. Review kernel cleanup separately after this workflow is stable.
~~~

### Switch discovery

~~~text
Command: cc system-update

Usage:
  cc system-update [switches]

Preview or apply managed OS and packaged-application updates.

Switches:
  --dry-run......... Preview package, Snap, and Flatpak operations without persistent mutation. [default]
  --apply........... Explicitly authorize implemented package, Snap, and Flatpak mutations.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
~~~

## cc toolkit-update

~~~text
Usage:
  cc toolkit-update [--dry-run|--apply]

Default:
  Dry-run. Reports the local repository state and planned installation without
  fetching, pulling, changing Git refs, creating backups, or installing files.

Options:
  --dry-run  Preview toolkit update and installation.
  --apply    Pull origin/main and run the full installer with explicit apply.
~~~

### Switch discovery

~~~text
Command: cc toolkit-update

Usage:
  cc toolkit-update [switches]

Preview or apply the toolkit Git and installer workflow.

Switches:
  --dry-run......... Inspect local state and preview update/install without Git or file mutation. [default]
  --apply........... Authorize origin/main pull and the full installer apply path.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
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
  1. toolkit-update       Preview or apply toolkit pull and shell-file installation.
  2. system-update        Run managed OS/app update workflow.
  3. kernel cleanup       Review obsolete kernels. Applies only with --apply.
  4. dev-update           Optional developer maintenance when explicitly enabled.
  5. verify               Verify repository structure and Bash syntax.
  6. doctor               Run toolkit health checks.
  7. drives / smart       Show storage inventory and SMART summary.
  8. status               Show repository status.

Notes:
  All mutation-capable stages receive an explicit --apply from this command.
  Use cc toolkit-update --dry-run to preview toolkit maintenance only.
  Use cc system-update --dry-run to preview package/app updates only.
  Use cc update dev --dry-run before applying developer package updates.
  Set DEV_UPDATES=yes in cc config to include developer updates in cc update --apply.
  Use cc kernel cleanup separately before trusting automated cleanup.
~~~

### Switch discovery

~~~text
Command: cc update

Usage:
  cc update [subcommand] [switches]

Run managed toolkit, system, kernel, health, and optional developer maintenance.

Switches:
  --dry-run............. Preview every enabled maintenance stage without persistent mutation. [default]
  --apply............... Pass explicit mutation authorization only to enabled mutation-capable stages.
  --toolkit-only........ Run only the toolkit maintenance stage.
  --system-only......... Run system update and kernel cleanup stages only.
  --health-only......... Run only verification and health reporting stages.
  --help, -h............ Show contextual command help.
  --version............. Show toolkit version information.

Subcommands:
  dev............... Target supported developer package managers.
  developer......... Alias for dev.
  developers........ Alias for dev.
  npm............... Target npm global packages.
  pipx.............. Target pipx applications.
  pip............... Report pip policy; mutation remains disabled.
  cargo............. Report cargo policy; mutation remains disabled.
  go................ Report Go policy; mutation remains disabled.
  gem............... Report RubyGems policy; mutation remains disabled.

Discovery:
  cc update <subcommand> switches
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

### Switch discovery

~~~text
Command: cc verify

Usage:
  cc verify [subcommand] [switches]

Verify repository structure, syntax, and command permissions.

Switches:
  --apply........... Repair command executable permissions only when executable verification is selected.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.

Subcommands:
  all............... Run repository verification.
  executable........ Inspect or repair command executable permissions.

Discovery:
  cc verify <subcommand> switches
~~~

## cc version

~~~text
Toolkit : 1.3.0-beta2
Codename: Blackbeard
Standard: 0.1.0
Baseline: ubuntu-26.04
Release : 2026-08-29
~~~

### Switch discovery

~~~text
Command: cc version

Usage:
  cc version

Show toolkit version and baseline information.

Switches:
  No command-specific switches.
  --help, -h........ Show contextual command help.
  --version......... Show toolkit version information.
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

### Switch discovery

~~~text
Command: cc workbench

Usage:
  cc workbench [subcommand] [switches]

Inspect or prepare a live USB drive-qualification workbench.

Switches:
  --apply.............. Authorize supported workbench preparation; omission is dry-run. [default: dry-run]
  --host-id ID......... Set the initialized workbench host identifier.
  --repo URL........... Use URL as the toolkit repository source.
  --target DIR......... Use DIR as the parent checkout directory.
  --no-selftest........ Skip the post-preparation engineering selftest.
  --help, -h........... Show contextual command help.
  --version............ Show toolkit version information.

Subcommands:
  prepare........ Inspect or prepare the workbench.
  status......... Show workbench status.

Discovery:
  cc workbench <subcommand> switches
~~~
