# Captain Cronos Shell Toolkit Administrator Guide

## Purpose
This guide is the primary operational reference for installing, configuring, maintaining, and updating the toolkit.

## Installation
- Clone the repository.
- For first-time shell enrollment, preview and run `install/install.sh`.
- Use `cc install` for launcher-only installation or repair.
- Verify with `cc version` and `cc doctor`.

`cc toolkit-update` is the recurring toolkit maintenance interface. It delegates
to the internal `install/update.sh` path, which updates Git only during explicit
apply and then invokes the full `install/install.sh` installer. `manifest.yml`
is metadata only in v1.3; it does not drive installation.

## Configuration
Use `cc config` to review and modify toolkit settings.

## PATH Management

Captain Cronos manages exactly `~/bin` and `~/.local/bin` through one marked
block in `~/.bashrc`. Check both the active PATH and startup configuration with:

```bash
cc env path
```

Inspection is read-only. Apply a repair explicitly with:

```bash
cc env path --fix
```

Repair creates missing managed directories, removes only recognized historical
Captain Cronos conditional prepends and marked guards, installs one canonical
block atomically, and preserves unrelated shell content, PATH entries, and
their relative ordering. Unrecognized PATH statements are retained and
reported for manual review rather than guessed at or deleted.

The repair process cannot alter the parent shell that launched `cc`. Its report
therefore distinguishes repaired startup configuration from inherited
duplicates still active in the current shell. After a successful repair, run
`source ~/.bashrc` to normalize the current interactive Bash session, or start a
new interactive shell. Repeated sourcing is safe and keeps each managed entry
exactly once.

## Daily Operations
- `cc update`
- `cc doctor`
- `cc repos status`
- `cc release check`

## Command and Switch Discovery

Start with `cc help` to discover public commands. Use the canonical `switches`
keyword to inspect one command without running it:

```bash
cc install switches
cc system-update switches
cc doctor switches
cc kernel switches
cc kernel cleanup switches
cc env path switches
```

Namespace discovery lists available subcommands and shows how to inspect a
narrower context. A command with no command-specific switches says so rather
than showing an empty list. Switch descriptions identify preview/apply defaults,
value requirements, and deliberate limitations where those distinctions affect
operator safety.

`switches` is read-only and is resolved before command dependencies or command
implementation code. `--help` remains the fuller command-owned reference and may
also include workflow notes and examples. Existing `-h` and namespace `help`
forms remain supported where they were already valid.

Unknown switches, unknown namespace actions, invalid positional arguments in
argument-free contexts, and missing switch values now include contextual help.
They remain errors: the renderer preserves usage status 2 and never authorizes a
mutation.

## Interactive Shell Helpers

The `cc` executable is the toolkit command dispatcher. It is not an alias for
the separate `helpme` shell-function index; the deprecated `cc='helpme'` alias
has been removed so it cannot shadow the dispatcher.

The former `edit-in-kitty` alias is replaced by documented shell functions:

- `kedit <file> [file...]` opens Nano in a detached Kitty terminal.
- `suedit <file> [file...]` opens Nano through `sudo` in a detached Kitty terminal.
- `sukitty` opens a detached Kitty terminal with an interactive root login shell.

These functions remain discoverable through `helpme` metadata and are not
`cc` subcommands.

## Kernel Health Reporting

`cc doctor` includes a concise semantic kernel check. Kernel `PASS`, `WARN`, and
`FAIL` propagate into the existing doctor summary, while a safely classified old
kernel cleanup candidate does not make the system unhealthy. Pending reboot or
a newer installed kernel is a `WARN` maintenance advisory, not corruption.

`cc monthly-health --stdout` provides the detailed view: running and newest
kernels, reboot state, package/initramfs/bootloader/EFI platform information,
installed/protected/candidate counts, boot and EFI utilization, artifact-state
counts, coded health findings, and maintenance advisories. The report is
read-only and never invokes kernel cleanup.

On reduced or unsupported platforms, the report preserves the platform's
semantic state rather than applying Linux artifact or package assumptions.

## Repository Publishing
Use `cc repos status` to review repository health before batch Git operations.
Its ahead/behind dashboard uses existing local remote-tracking refs and clearly
states that it does not refresh the network. Use an explicitly authorized
`cc repos fetch --apply` or `cc repos sync --apply` when fresh remote state is
required. Batch actions continue through independent repositories, summarize
PASS/WARN/FAIL/SKIP results, and return nonzero when any required action fails.

```bash
cc repos push
cc repos push --apply
```

`cc repos push` is dry-run by default. With `--apply`, it skips dirty repositories, skips repositories without an `origin` remote, reports ahead/behind state, and pushes only repositories that are ahead of their origin branch. It never force pushes and continues through remaining repositories after failures.

```bash
cc repos publish
cc repos publish --apply
```

`cc repos publish` is the strict publishing path for completed work. With `--apply`, each detected repository must have a clean working tree, must be on `main`, and must have an `origin` remote before the command runs `git push origin main`. Repositories that do not meet those checks are skipped, and failures do not stop the remaining repositories from being processed.

## Update Operations
`cc update`, `cc toolkit-update`, and `cc system-update` default to zero-write
preview mode. Persistent package, Git, backup, or installed-file changes require
an explicit `--apply`; unknown options are rejected. Toolkit preview inspects
only local Git state because fetching would modify repository metadata.
Toolkit apply requires a clean `main` branch and an `origin` remote, then uses a
fast-forward-only pull before passing explicit apply authorization to the full
installer.

`cc system-update` is the OS and packaged desktop application update path. It
applies semantic system package operations plus detected Snap and Flatpak updates
only with `--apply`. On Debian-family systems, Captain Cronos automation resolves
`apt-get`, `apt-cache`, and `dpkg` through the Program Management System; `apt`
remains suitable for direct interactive terminal use.

Automatic Firefox/Thunderbird tar archive replacement and CLI Safe Boot/GRUB
rewrites are deferred for the v1.3 RC. Routine system update never performs
those operations, including during `--apply`.

Developer package managers are intentionally report-only during normal system updates because they can change project build tools, language runtimes, global CLIs, user environments, or workstation-specific workflows. Normal `cc system-update` reports npm, pipx, pip, cargo, go, and gem as installed or not installed, shows whether update application is enabled, and prints the dry-run command to review.

Use the maintenance previews before applying changes:

```bash
cc update --dry-run
cc toolkit-update --dry-run
cc system-update --dry-run
cc update --apply
```

Use explicit developer update commands when you want that surface:

```bash
cc update dev --dry-run
cc update npm --dry-run
cc update dev --apply
```

Mutating developer updates require `--apply`. To include supported developer ecosystem updates in the full `cc update --apply` workflow, opt in explicitly:

```bash
cc config set DEV_UPDATES yes
```

The default remains:

```bash
DEV_UPDATES="no"
```

## Network Inspection

Captain Cronos reads Linux interface, address, and route state through the
configured `ip` interface and socket/listener state through `ss`. These are
read-only inspection paths. Connectivity checks such as `ping`, DNS tools, and
NetworkManager control have distinct purposes and are not replaced by `ip` or
`ss`.

## Services and Logs

Captain Cronos resolves systemd service operations through the configured
`systemctl` interface and system logs through `journalctl`. Internal operations
always distinguish system units from `systemctl --user` units. Status and log
queries are unprivileged; system-level mutations apply privilege escalation only
inside the service library.

The optional monthly-health timer is a user unit. Its install, enable, disable,
status, and daemon-reload operations remain user-scoped and do not use `sudo`.

## Downloads and HTTP APIs

Captain Cronos distinguishes file downloads from HTTP/API requests. Release
archives and other destination-oriented files use the configured `wget`
download interface. API-oriented GET or HEAD requests use the configured `curl`
interface so HTTP status, redirects, and response output are handled explicitly.

TLS certificate verification is enabled by default. HTTP failures return failure
status, dry-run retrieval performs no transfer, and credential-bearing URL
components are redacted from dry-run reports.

## JSON and YAML

Captain Cronos resolves JSON processing through `jq` and YAML processing through
the Kislyuk yq jq-wrapper. An executable named `yq` is not sufficient: several
unrelated implementations use that name with incompatible command syntax.
`cc programs` reports `INCOMPATIBLE` when the configured executable exists but
does not provide the required interface.

No arbitrary minimum yq version is required. Compatibility is established by
the implementation identity and a behavioral query/serialization probe. YAML is
required by asset and drive workflows. JSON remains optional and is used by
explicit JSON output modes. Checks are observational and never install or
replace a processor.

## Storage Workflow
1. `cc drive-report`
2. `cc drive-qualify`
3. `cc asset inventory drives`
4. `cc drive-burnin` (framework)

## Kernel Workflow

Use `cc kernel status`, `cc kernel list`, and `cc kernel running` for read-only
inspection. Use `cc kernel platform` to see the detected distribution package
model, initramfs provider evidence, EFI runtime, and exactly which Captain
Cronos operations are supported. Use `cc kernel artifacts` for detailed package, ownership, kernel,
initramfs, map, and config correlation; use `cc kernel health` for a concise
PASS/WARN/FAIL assessment. `cc kernel cleanup` is also read-only by default and prints the
candidate package plan. Only `cc kernel cleanup --apply` permits package
mutation. The running release is always protected. The nearest verified older
release is protected as a fallback, the newest verified release newer than the
running kernel is protected as pending reboot, and `KEEP_COUNT` protects that
many newest non-running installed sets. Uncertain mappings are retained and
never become cleanup candidates.

Cleanup is enabled only on supported Debian-family package systems. A candidate
must have exactly one installed image package, a regular version-matched kernel
artifact, and exactly one matching package owner. The complete purge plan is
shown without mutation unless `--apply` is explicit; apply performs only the
bounded purge and leaves bootloader work to Debian package lifecycle hooks. A
reboot marker and a newer verified installed kernel are reported as distinct
states. The legacy `cc kernel-cleanup` form delegates to the same implementation.

Status distinguishes the boot path from its backing filesystem. “Boot
filesystem usage” is capacity utilization of the filesystem containing `/boot`;
“/boot artifacts” is the allocated space actually consumed below the boot path
without crossing into a separately mounted EFI filesystem. EFI source, type,
size, used, available, and utilization are reported independently when a known
EFI path is mounted.

Artifact states are `MATCHED`, `MISSING`, `UNMATCHED`, `PARTIAL`, or `UNKNOWN`.
Treat every state other than `MATCHED` as a prompt for inspection, not deletion.
Health warnings include correlation issues, pending reboot state, and boot or
EFI filesystems at least 90 percent utilized. Only boot-path inspection failure
or a missing/unsafe running kernel image produces a health failure.

Initramfs tools are detected rather than configured as interchangeable Program
Management choices. If multiple providers are installed, the platform report
shows a primary provider only when package/configuration/executable evidence is
stronger; equal evidence is `ambiguous`. Regardless of detection, kernel
installation, initramfs regeneration, and bootloader mutation are not
implemented.

Only the Debian package model currently supports exact package correlation and
cleanup. RPM, Arch, and openSUSE package models are identified for inspection
and future adapters, but cleanup remains unsupported. `cc kernel deps` reports
core requirements, optional filesystem/package capabilities, all provider
signals, the selected provider, and the read-only mutation policy.

EFI reporting distinguishes a mounted filesystem from active EFI firmware
runtime. The former indicates accessible EFI storage; only the latter indicates
that the running kernel exposes EFI runtime services.

## Documentation
- `cc docs inventory`
- `cc docs build --apply`
- `cc docs lint`

## Releases
Run `cc release check` before every tagged release.

## Local Development Validation

Use `ccvalidate fast` for inexpensive feedback and `ccvalidate full` for the
normal local acceptance gate after implementation. Bare `ccvalidate` defaults
to full. Use `ccvalidate release` for release-equivalent coverage plus the
release-readiness gate. These three modes are read-only validation workflows.

After reviewing a clean committed feature, fix, or development branch, run
`ccvalidate finish` to perform the explicit ShellToolkit Git completion flow.
It refuses main, dirty/staged/untracked work, missing or suspicious origins,
uncommitted feature work, and any history that cannot fast-forward. It validates
the feature before changing branches, updates and merges main with `--ff-only`,
revalidates before pushing only main to origin/main, verifies the remote commit,
and deletes the local feature branch with `git branch -d` only after success.

If finish has already fast-forwarded the feature into local main but stops at
post-merge release validation, correct and commit the defect on local main and
run `ccvalidate publish`. Publish is a constrained continuation, not a general
push or merge command. It requires the recognized ShellToolkit repository,
clean main, the canonical fetch/push origin, and non-diverged fast-forward
publication topology. It runs release validation, fetches again, and stops if
remote main changed during the workflow. It pushes only local main to
`origin/main`, without tags or force, then compares local main, the
remote-tracking ref, and live `ls-remote` output.

Finish records the retained branch and merge commits in local Git-private
workflow state. That marker helps publish identify cleanup ownership but never
overrides current Git topology. After verified publication, publish deletes the
local retained branch only when its tip still matches the marker and
`git branch --merged main` proves it merged. Invalid or missing state, a moved
branch, or failed safe deletion is reported without guessing; remote feature
branches are never deleted. An already-published main is verified idempotently
and is not pushed again.

If validation fails before the branch switch, nothing is pushed and the feature
checkout is left untouched. If validation fails after a local merge, nothing is
pushed or reset and the feature branch remains for `ccvalidate publish` or
operator review. There is no automatic rollback. The workflows never
auto-stash, force-push, rebase, rewrite history, resolve conflicts, delete remote
feature branches, or change packages, kernels, bootloaders, browsers, services,
PATH configuration, or unrelated repositories.

## Persistent Resource Retention

Use `cc maintenance inventory` to inspect every cataloged persistent resource.
It reports subsystem, lifecycle class, location, count, size, oldest/newest
dates, policy, cleanup state, ownership rule, scan warnings, and skipped
symlinks. `cc maintenance inventory --format tsv` provides stable machine-readable
output. `cc maintenance status` is the concise view used by monthly health, and
`cc maintenance retention` explains the policy model.

`cc maintenance cleanup` and `cc maintenance cleanup --dry-run` are identical
read-only previews: v1.3 selects zero candidates. There is deliberately no
`--apply` switch. Installer recovery generations are incomplete/partial and no
minimum recovery guarantee exists; report comparison value has no objective
expiry; asset history is curated; bundles are explicit user exports; and legacy
or unclassified paths lack deletion-grade ownership proof.

Canonical host-scoped reports, assets, logs, cache, and plugins live below
`~/.captaincronos/hosts/<host-id>/`. Installer backups and repository bundles
remain global under `~/.captaincronos/`. Existing legacy reports, assets,
`~/upgrade.log`, and `~/kernel-cleanup.log` are inventoried conservatively but
never deleted. Inventory does not follow symlinks or scan arbitrary home paths.
Optional monthly-health service/timer files are inventoried by exact name, but
their existing `cc monthly-health-timer retire` workflow remains their sole
lifecycle owner; retention cleanup does not touch them.

Monthly health includes only a concise retention status and never cleans
persistent resources. Doctor does not treat ordinary historical accumulation as
a failure; no new retention doctor gate or policy configuration is introduced.

## Backups
Preserve `~/.captaincronos/` as part of system backups. Asset records and
history are authoritative or curated, installer generations provide recovery,
and explicit repository bundles remain operator-managed exports.
