# Captain Cronos Shell Toolkit Architecture

## Overview
Captain Cronos Shell Toolkit is a modular Linux administration framework built around shell commands, shared libraries, generated documentation, local configuration, reports, and asset records.

## Repository Layout

```text
CaptainCronos-01-ShellToolkit/
  VERSION
  lib/
  tools/
    cc
    commands/
  plugins/
  docs/
  docs/generated/
```

## Core Concepts

### Front End
`tools/cc` is the command front end. It dispatches subcommands from `tools/commands/`.

### Commands
Each executable command lives in `tools/commands/` and provides its own help, version, and metadata header.

### Shared Libraries
Common behavior belongs in `lib/`.

Important libraries:

- `cc-common.sh` — banner, logging, shared display behavior
- `cc-diagnostics.sh` — debug diagnostics, redaction, and TTY-aware workflow progress
- `cc-config.sh` — toolkit configuration helpers
- `cc-path.sh` — managed PATH policy, startup auditing, and atomic repair
- `cc-programs.sh` — configured command-line capability resolution
- `cc-packages.sh` — semantic, platform-aware system package operations
- `cc-kernel.sh` — kernel discovery, ordering, classification, ownership, and reboot-state inspection
- `cc-network.sh` — semantic, platform-aware network-state inspection
- `cc-services.sh` — scoped service lifecycle, timer, and system-log operations
- `cc-http.sh` — semantic file downloads and HTTP/API requests
- `cc-data.sh` — compatible JSON/YAML validation, queries, and YAML mutation
- `cc-deps.sh` — semantic capability and literal executable dependency checks
- `cc-yaml.sh` — compatibility API for existing asset YAML operations
- `cc-metadata.sh` — command metadata and registry helpers
- `cc-assets.sh` — local asset database helpers
- `cc-retention.sh` — persistent ownership catalog and bounded storage accounting
- `cc-prompt-engine.sh` — internal prompt template discovery, rendering, and formatting helpers

### Terminal Presentation Contract

Commands retain semantic state as plain PASS, WARN, FAIL, SKIP, or INFO values.
`cc-results.sh` aggregates those values without inspecting display text, and
`cc-common.sh` renders them through shared status-word, dotted-leader row,
summary, and diagnostic helpers. The general dotted-leader renderer also keeps
plain label/value inventories such as `cc help` readable without coupling their
meaning to color. `cc-diagnostics.sh` uses the status renderer for completed
progress rows. Exit status remains authoritative; neither commands nor tests
derive results from ANSI sequences.

Color is semantic rather than decorative: PASS is green, WARN yellow, FAIL and
ERROR red, SKIP cyan, and INFO or ordinary data use the terminal default.
Automatic color requires the destination stream to be a TTY. `NO_COLOR`,
`TERM=dumb`, or `CC_COLOR_MODE=never` suppress it; `CC_COLOR_MODE=always` is a
focused rendering/test override. Generated documents, reports, pipes, and files
therefore remain uncolored in normal operation. Tables remain tables, while
primary semantic cells may use the shared status-word renderer.

### Configuration
User configuration is stored under:

```text
~/.captaincronos/config
```

Use `cc config` to view or modify it.

Command `Requires` metadata may name either a Program Management capability or
a literal executable. The dependency layer resolves known capabilities through
`cc-programs.sh`, preserving compatibility status, and generates package hints
only for literal executable dependencies. Capability-specific platform adapters,
such as the package library's native manager resolver, plug into this generic
dependency contract without teaching the dispatcher executable mappings.

### Managed PATH Architecture

`lib/cc-path.sh` is the single Captain Cronos policy owner for `~/bin` and
`~/.local/bin`. It generates the marked managed block deployed in
`bash/bashrc`, audits installed startup configuration, classifies exact legacy
writers, and performs atomic `.bashrc` repair. The full installer and toolkit
update deploy the authoritative shell file; they do not maintain a separate
PATH prepend.

The managed block runs after NVM and other content in the authoritative
`.bashrc`. On every source it preserves the first occurrence and position of
each managed entry, removes later occurrences of those entries, inserts missing
managed entries, and leaves unrelated PATH entries in their existing relative
order. Repeated sourcing must therefore produce the same managed PATH state.
Guarded `.profile` insertion remains compatible and `.profile` is not written
by ShellToolkit.

`cc env` and `cc env path` only inspect. Persistent repair requires
`cc env path --fix` (with `--apply` retained as a compatibility spelling).
Repair removes only exact historical conditional prepends and exact marked
Captain Cronos guards for the two managed directories. Ambiguous or user-owned
PATH statements are preserved and reported. Repair uses same-directory secure
staging, preserves an existing file's mode, refuses symlinked or non-regular
targets, and replaces `.bashrc` atomically only when content changed.

A command process cannot change its parent shell environment. Successful repair
therefore distinguishes startup-file state from the PATH already active in the
invoking shell and directs the administrator to source the repaired `.bashrc`
or start a new interactive shell.

### Update Architecture
Maintenance updates are split into three surfaces:

- System package operations: semantic update, upgrade, install, removal, query, and database interfaces resolved through the platform and Program Management layers.
- Desktop/app package managers: detected Snap and Flatpak interfaces managed by `cc system-update`.
- Developer ecosystem package managers: npm, pipx, pip, cargo, go, and gem.

`cc system-update` owns system and packaged desktop/app updates. It detects and
reports developer ecosystem package managers, but does not update them. Direct
Firefox/Thunderbird archive replacement and CLI Safe Boot/GRUB rewriting are
deferred for the v1.3 RC and are unreachable from routine update. This protects
project toolchains, global CLIs, language-specific package state, browser
installations, and boot configuration from broad workstation maintenance runs.

### Mutation Contract

Mutation-capable maintenance and installation commands default to inspection or
preview. `--dry-run` is zero-write, `--apply` is the only authorization for
persistent changes, unknown options fail nonzero, and child commands receive the
parent's explicit mode. In particular:

```text
cc update --apply
  +-- cc toolkit-update --apply
  |     +-- install/update.sh --apply
  |           +-- install/install.sh --apply
  +-- cc system-update --apply
  +-- cc kernel cleanup --apply
```

Dry toolkit preview uses existing local branch, HEAD, remote configuration, and
upstream refs only. It does not fetch. Installer preview reports source,
destination, mode, and planned backups without creating them. System-update
logging is persistent only during explicit apply. Monthly-health invokes the
same system-update dry-run contract for update readiness.

Monthly-health records every significant subsystem as PASS, WARN, FAIL, or
SKIP. FAIL takes precedence over WARN, WARN over PASS, and SKIP remains visible
without failing the command. Any FAIL makes the command exit nonzero. Persistent
reports and their staging files are private (0600), and report output is
redacted for user/home/repository identity, credential-bearing URLs, HTTP
authorization/cookie fields, and common inline secret assignments.

On Debian-family systems, toolkit automation uses the configured `apt-get` interface for package operations, `apt-cache` for repository queries, and `dpkg` for the installed-package database. Interactive administrators may still use `apt` directly at a terminal. Other supported platform families retain their native package-manager syntax behind `lib/cc-packages.sh`.

### Kernel Management Architecture

`lib/cc-kernel.sh` is the single kernel inspection and classification layer.
On supported Debian-family systems it captures the installed package inventory
once per command, derives versioned sets from exact `linux-image-*` package
names, and orders releases with Debian package-version comparison. Set mapping
separately verifies a regular `/boot/vmlinuz-*` artifact and its unique package
owner. List, status, health, and cleanup consume this prepared inventory.

Protection and eligibility are separate. The running release is always
protected. A verified nearest-older release is protected as the known fallback,
the newest verified release newer than the running kernel is protected as the
pending-reboot target, and `KEEP_COUNT` retains the newest additional installed
sets even when their mapping is uncertain. Only verified sets outside all of
those protections become cleanup candidates.

Cleanup mutation is currently supported only for the Debian-family package
adapter. A version is eligible only when exactly one installed image package,
a regular version-matched boot artifact, and exactly one matching package owner
are present. Ambiguous, missing, symlinked, or mismatched evidence retains the
set. Dry-run prints the immutable bounded package plan and writes no cleanup
log. Explicit apply rechecks the running release and its verified mapping, then
performs only the planned purge; it does not run unbounded autoremove or clean
operations. Shared header packages are retained while any non-candidate set
still references them.

Debian kernel packages run bootloader maintenance through package lifecycle
hooks, so kernel cleanup does not invoke `update-grub` directly. Non-Linux hosts
can report the running kernel but return reduced/unsupported state for Linux
inventory and cleanup operations.

Boot storage uses three independent observations. `findmnt --target` identifies
the real filesystem and mountpoint containing `/boot`; this may be `/` rather
than a dedicated boot mount. `du -skx` measures actual allocation beneath the
boot path without crossing into nested filesystems or following symlink targets.
An exact mounted-filesystem query independently reports `/boot/efi` or `/efi`
capacity when present, so EFI contents are not charged to ordinary `/boot`
consumption.

The artifact model correlates versioned `vmlinuz-*`, `initrd.img-*` or
`initramfs-*.img`, `System.map-*`, and `config-*` files with installed image
packages and package ownership. Regular files are inspected by metadata only;
versioned symlinks are `UNKNOWN` and are never followed. NUL-delimited discovery
handles filenames safely, while releases containing control separators are
isolated from classification.

Correlation states are conservative: `MATCHED` is a complete owned set;
`MISSING` means an installed image package lacks a kernel or initramfs artifact;
`UNMATCHED` means artifacts have no exact installed image package; `PARTIAL`
means non-critical map/config metadata is absent; and `UNKNOWN` covers unsafe
symlinks, ambiguous packages, or unresolved ownership. `UNMATCHED` never implies
safe deletion.

Health is `FAIL` only for an inaccessible/unidentifiable boot path or a missing
or unsafe running kernel image. Inconsistencies, reboot state, and boot/EFI
filesystem utilization at or above 90 percent are `WARN`. A fully correlated
set with no findings is `PASS`. Bootloader inspection reports only directory
evidence for GRUB, systemd-boot, EFI presence, or an unknown environment and
never executes boot artifacts or management utilities.

### Kernel Environment and Capability Model

Kernel environment detection is distinct from operation support. The shared
kernel library classifies Debian, RPM, Arch, openSUSE, unknown Linux, and
non-Linux environments using OS identity first and the package-manager family
as a fallback. Each family exposes a descriptive package model without implying
that Captain Cronos can correlate or remove its packages.

Current support is:

| Environment | Running inspection | Artifact inspection | Package correlation | Cleanup mutation |
|---|---:|---:|---:|---:|
| Debian family | yes | yes | yes | yes, Debian adapter only |
| Fedora/RHEL RPM family | yes | yes | not implemented | no |
| Arch family | yes | yes | not implemented | no |
| openSUSE family | yes | yes | not implemented | no |
| Unknown Linux | yes | yes when `/boot` is readable | no | no |
| Non-Linux | running release only | no Linux semantics | not applicable | no |

RPM hosts are modeled around versioned `kernel-core`, `kernel-modules`,
`kernel-modules-extra`, and related RPM instances. Arch is explicitly modeled
around pkgbase names such as `linux`, `linux-lts`, and `linux-zen`, which do not
encode the complete running release like Debian package names. openSUSE is
modeled around versioned `kernel-<flavor>` RPM instances such as
`kernel-default`. These are detection models for future exact correlation, not
cleanup adapters.

Initramfs provider detection evaluates `initramfs-tools`/`update-initramfs`,
dracut, and mkinitcpio using executable, installed-package, and configuration
evidence. Package and configuration evidence carry more weight than executable
presence. A unique strongest provider is primary; other detected providers are
reported separately; tied evidence is `ambiguous`. Provider detection supports
read-only artifact interpretation only. Initramfs regeneration remains not
implemented.

Provider tools are intentionally absent from `config/programs.conf`. They are
platform-specific implementations with different package hooks, presets,
configuration, and output models—not interchangeable administrator preferences.
The kernel capability layer detects them, while the package layer supplies
semantic installed-package and database-availability queries.

EFI filesystem state and EFI runtime state are independent. A mounted known EFI
path produces `present`; `/sys/firmware/efi` produces runtime `active`. A mounted
EFI filesystem does not prove the current kernel booted through EFI. Bootloader
detection remains observational and Linux-scoped. Kernel installation,
initramfs mutation, and bootloader mutation are always reported as not
implemented.

### Kernel Health Consumers

The kernel library exposes a transient semantic snapshot for command-level
consumers. A capture evaluates health findings once, records stable scalar
fields for running/newest releases, platform, reboot state, inventory, boot
storage, EFI, and artifact-state counts, and retains coded findings in memory
for the current shell process. It does not create a persistent cache.

Findings use `severity<TAB>code<TAB>message`. Stable codes include
`REBOOT_REQUIRED`, `NEWER_KERNEL_AVAILABLE`, `BOOT_USAGE_HIGH`,
`EFI_USAGE_HIGH`, `ARTIFACT_PARTIAL`, `ARTIFACT_UNMATCHED`,
`ARTIFACT_MISSING`, `ARTIFACT_UNKNOWN`, and
`RUNNING_KERNEL_ARTIFACT_FAILURE`. The shared status reducer preserves
`PASS < WARN < FAIL`; commands do not derive severity from display text.

`cc doctor` captures one snapshot, maps its severity into the existing doctor
warning/failure counters, and prints only the running release, concise platform
summary, and non-PASS reasons. `cc monthly-health` captures one snapshot for its
richer, stable kernel section. Its embedded doctor invocation skips a second
kernel capture. Neither consumer invokes or parses `cc kernel` commands.

Cleanup candidates are deliberately absent from health severity. Monthly health
reports them under maintenance, while doctor remains PASS when kernel health is
PASS. Reboot-required and newer-kernel states are WARN advisories, never hard
corruption failures. Reduced non-Linux inspection is reported semantically and
does not enable Linux package or cleanup behavior.

`cc dev-update` owns developer ecosystem reporting and explicit mutation. It defaults to dry-run/reporting. Mutating developer updates require `--apply`; only package managers with a conservative global update path are applied. Normal `cc update --apply` includes developer updates only when `DEV_UPDATES=yes` is set in toolkit config.

### Network Inspection Architecture

On Linux, interface, address, and route inspection resolves the configured `ip`
capability. Listener and connection inspection resolves the configured `ss`
capability. Shared helpers use one-record and headerless output where practical,
and active commands consume those helpers instead of selecting executables.

FreeBSD-native `ifconfig`, `route`, `netstat`, and `sockstat` behavior remains
behind explicit platform branches. NetworkManager configuration, resolver/DNS
inspection, reachability probes, and network scanning are separate capabilities;
they are not treated as substitutes for kernel network or socket state.

### Service and System Log Architecture

On systemd Linux hosts, service lifecycle and unit/timer inspection resolves the
configured `systemctl` capability, while journal inspection resolves
`journalctl`. Higher-level commands use semantic helpers and must pass either
`system` or `user`; user services are never silently promoted to system scope.

State tests use command exit status and machine-oriented properties rather than
parsing status screens. Read-only queries run without privilege escalation.
System mutations add `sudo` in the execution library, user mutations do not, and
dry-run mode reports commands without executing them. OpenRC and FreeBSD rc
behavior remains behind explicit platform branches.

### HTTP and Download Architecture

HTTP retrieval is split by semantics. File acquisition resolves the configured
`wget` download interface and preserves destination, redirect, retry, overwrite,
diagnostic, and failure behavior. API-style GET and HEAD requests resolve the
configured `curl` interface and emit response data without progress decoration.

Both paths fail on HTTP errors, follow required redirects, and retain TLS
certificate verification by default. Dry-run reports redact URL credentials and
query strings and perform no transfer. Authentication, request headers, and
mutating HTTP methods are not abstracted until an active caller requires them.

### Structured Data Architecture

JSON validation, querying, and generation resolve the configured `jq` interface.
YAML validation, querying, generation, and mutation resolve the configured Kislyuk
`yq` jq-wrapper interface. Expressions are passed as individual arguments and
data values use processor arguments; neither path uses `eval` or sources data.

Program status distinguishes executable presence from interface compatibility.
JSON compatibility uses a jq behavior probe. YAML compatibility requires the
Kislyuk version identity form plus the YAML output and jq-expression behavior
used by the toolkit. No minimum yq version is imposed beyond passing that probe.
Asset YAML writes use securely named temporary files and atomic replacement.

YAML is required because active asset and drive commands read and mutate YAML.
JSON remains optional because prompt and selftest JSON output modes are optional;
their non-JSON behavior does not depend on jq.

### Reports
Historical reports are stored under:

```text
~/.captaincronos/hosts/<host-id>/reports/
```

Reports represent timestamped observations. Monthly-health reports remain mode
0600 inside a mode-0700 directory and keep a `latest.log` symlink for operator
convenience. Drive reports and qualification captures are historical records.
They contain device, serial, host, and health data, so new drive report files
are mode 0600 inside mode-0700 directories. The v1.3 policy retains all report
history because no objective expiration rule has been established.

### Diagnostics and Progress

Commands enable the single shared debug state after parsing `--debug`.
Framework diagnostics use stderr, apply common secret redaction, and never
contaminate human or structured stdout. Multi-stage commands use authoritative
stage counts and identify the current activity; interactive terminals may use a
live status line, while pipes and logs receive stable line-oriented results.
Debug mode always uses sequential diagnostic and activity lines.

The first primary consumer is `cc selftest --debug`. Program, dependency,
platform/package, service, configuration, SMART, and storage helpers expose
representative decision diagnostics without global shell tracing.

### Temporary Resource Ownership

`lib/cc-temp.sh` owns secure temporary files and directories created by toolkit
production code. Creation and registration occur together in the current shell;
the per-process registry records the exact absolute path, resource type, owner,
device, and inode. Cleanup never scans a directory or accepts a wildcard. A
changed identity, unsafe path, or ownership mismatch is left untouched.

Registered resources are removed deterministically by their consumer and again
as a safe no-op at process exit. Lazy EXIT, INT, and TERM hooks preserve handlers
that existed before the first allocation. Catchable INT and TERM perform cleanup,
run the prior handler, and retain conventional statuses 130 and 143. SIGKILL is
inherently uncatchable, so no producer can guarantee cleanup after it.

Destination-adjacent staging files use the same secure creation path. After an
atomic rename succeeds, the old staging name is explicitly unregistered; the
published destination is never registered for cleanup. On failure or catchable
interruption, only the exact still-registered staging resource is eligible for
removal. Test fixtures and caller-selected destinations are not toolkit cleanup
roots.

### Persistent Resource Ownership and Retention

Persistent files intentionally outlive one command and therefore never enter
the `cc-temp` registry. `lib/cc-retention.sh` defines the read-only ownership
catalog used by `cc maintenance`. A path is deterministically classifiable only
when it is under a canonical `CC_HOME`/host root or is an exact path or filename
produced by a known command. Merely residing under `HOME` proves nothing.

The lifecycle classes are authoritative state, user-curated state, historical
record, regenerable cache, recovery artifact, user export, and unknown/external.
Every v1.3 policy is preservation-first: `retain` or `user-managed`. Cleanup is
disabled, there is no `--apply` interface, symlinks are counted but never
followed, and scans are bounded to known roots without crossing filesystems.

| Subsystem / producer | Canonical or exact location | Class | Accumulation | Policy | Cleanup |
|---|---|---|---|---|---|
| host initialization / configuration | `CC_HOME/config`, `CC_HOST_HOME/config` | authoritative state | replaced in place | retain | never |
| `cc monthly-health --file` | `CC_REPORT_DIR/monthly-health/` | historical record | timestamped reports plus latest symlink | retain | disabled |
| `cc drive-report`, `cc drive-qualify` | `CC_REPORT_DIR/drives/` | historical record | timestamped report directories | retain | disabled |
| asset commands and drive workflows | `CC_ASSET_DIR/` | authoritative state | records replaced in place | retain | never |
| asset history appenders | `CC_ASSET_DIR/.history/` | user-curated state | append-only logs | retain | never |
| full installer / toolkit update | `CC_HOME/backups/` | recovery artifact | timestamped partial generations | retain | disabled |
| `cc repos backup --apply` | `CC_HOME/repo-bundles/` | user export | timestamped Git bundles | user-managed | never |
| system update apply | `CC_LOG_DIR/system-update.log` | historical record | replaced per apply | retain | disabled |
| kernel cleanup apply | `CC_LOG_DIR/kernel-cleanup.log` | historical record | append-only | retain | disabled |
| optional monthly-health timer | `~/.config/systemd/user/captaincronos-monthly-health.{service,timer}` | authoritative state | replaced in place | retain | owner command only |
| host plugins | `CC_HOST_HOME/plugins/` | user-curated state | operator/plugin managed | user-managed | never |
| reserved cache root | `CC_CACHE_DIR/` | regenerable cache | no active producer | retain | disabled |
| helpme refresh backup | `~/.bash_functions.pre-helpme-refresh.*.bak` | recovery artifact | timestamped files | retain | disabled |
| legacy reports/assets/logs and unclassified `CC_HOME` entries | exact legacy paths | unknown/external | unknown | retain | never |

Caller-selected `cc repos inventory --out` files are user exports outside the
catalog. Temporary report staging remains ephemeral and belongs exclusively to
`cc-temp`. Release and verification transcripts are emitted to the caller or
temporary fixtures; no active producer intentionally persists them.

Repository outputs under `baseline/`, `defaults/`, and `docs/generated/` are
version-controlled source/reference artifacts whose lifecycle belongs to Git
and their engineering commands, not host retention. Installed shell files,
`~/bin/cc`, and managed PATH content may contain user customization and are not
claimed as deletion-owned. Workbench checkouts and caller-selected inventory
exports are user-managed. Archived migration scripts are inactive producers.

### Assets
Current lifecycle state is stored under:

```text
~/.captaincronos/hosts/<host-id>/assets/
```

Assets represent current inventory state.

### Plugins
Plugins are organized under:

```text
plugins/
```

Current reserved plugin areas include:

- storage
- repository
- maintenance
- bitcoin

### Prompt Engine
The internal prompt engine lives in:

```text
lib/cc-prompt-engine.sh
templates/prompts/
```

It discovers prompt templates from metadata headers, reads interactive question
definitions, tracks reusable session state, validates answers, substitutes
`{{variables}}`, renders prompt bodies, and applies output formatting hooks.
The public `cc prompt` command builds its menu from discovered template metadata
and then calls the shared engine for session navigation, validation, rendering,
and clipboard support. Adding a new `*.prompt` file makes that template
available without command-shell changes.

### Documentation
Generated documentation is stored under:

```text
docs/generated/
```

Manual documentation lives under:

```text
docs/
```

### Documentation Ownership

The repository `VERSION` file is the sole toolkit version and codename authority.
Root `ROADMAP.md` is the roadmap authority. `CHANGELOG.md` is the release-history
authority. Command headers and the command registry are the metadata authority
for command discovery; `cc docs build --apply` derives the command inventory and
reference under `docs/generated/`. Generated documents are build artifacts and
must not be hand-maintained as competing sources.

`docs/ARCHITECTURE.md` owns architecture, `docs/ADMINISTRATOR_GUIDE.md` owns
administrator procedures, and `docs/RELEASE_1.3_CHECKLIST.md` owns the 1.3
release checklist.

Installation ownership is deliberately split: `cc install` is the normal
launcher-only interface; `install/install.sh` is the full shell/toolkit
installer; `cc toolkit-update` delegates to `install/update.sh`, which performs
the Git update and then calls the full installer. The two scripts under
`install/` are implementation paths, not additional public command namespaces.

### Release Workflow
`cc release check` is read-only and validates version state, repository checks,
strict audit, documentation lint and freshness, Bash syntax, ShellCheck policy,
secure temporary-file policy, release-document consistency, and the working
tree before release activity.

Local acceptance is orchestrated by the canonical `ccvalidate` function from
`bash/bash_functions`, promoted unchanged through `defaults/v1/bash_functions`.
Its `fast`, `full`, and `release` modes are validation-only. Full mode relies on
the selftest's default release gate rather than repeating its verify, audit, and
documentation stages. Release mode delegates that internal gate and invokes it
once as an explicit final stage. Explicit `finish` and `publish` modes form the
Git-mutation boundary. Finish owns the feature checkout, fast-forward main
update/merge, and post-merge validation. After the verified merge it records
Git-private continuation evidence containing repository/remote identity,
feature branch and tip, merged main, and the observed origin/main. A post-merge
failure leaves local main, the retained feature, and that marker intact without
pushing or resetting.

Publish owns continuation from clean local main. It accepts only equal or
strictly-ahead, non-diverged main topology; runs release validation; rejects a
remote ref change between its before/after fetches; and shares finish's exact
main-only push, local/tracking/live verification, and safe cleanup helpers. The
state marker identifies a candidate but is never authoritative: deletion also
requires the unchanged recorded tip and membership in
`git branch --merged main`, and uses only `git branch -d`. Successful verified
publication can stand with a cleanup warning when ownership is unknown or
deletion is unsafe. No
rollback, force, reset, rebase, stash, tag push, or remote-feature deletion path
exists.

Generated command references execute repository help under a canonical root,
C locale, ANSI-disabled presentation, and without caller shell hooks or custom
program mappings. Help bypasses runtime dependency checks, while every help and
switch-rendering failure propagates through aggregate generation. A failed or
partial render is therefore a generation error, never a stale-document result.

## Design Rules

- Commands should be small and composable.
- Long workflows should orchestrate existing commands instead of duplicating logic.
- Read-only commands should remain separate from destructive workflows.
- Reports and assets should remain separate.
- Every command should expose metadata for registry and documentation generation.
