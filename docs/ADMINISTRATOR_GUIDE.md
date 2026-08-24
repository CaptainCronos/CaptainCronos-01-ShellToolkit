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
mutation. Set `KEEP_COUNT` to a non-negative integer to protect that many newest
non-running kernels in addition to the running kernel.

Cleanup is enabled only on supported Debian-family package systems. Package
ownership must be unambiguous; otherwise the release is retained. A reboot
marker and a newer installed kernel are reported as distinct states. The legacy
`cc kernel-cleanup` form remains supported.

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

## Backups
Preserve both ~/.captaincronos/assets and ~/.captaincronos/reports as part of system backups.
