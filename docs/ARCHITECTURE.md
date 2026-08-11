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
- `cc-prompt-engine.sh` — internal prompt template discovery, rendering, and formatting helpers

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

On Debian-family systems, toolkit automation uses the configured `apt-get` interface for package operations, `apt-cache` for repository queries, and `dpkg` for the installed-package database. Interactive administrators may still use `apt` directly at a terminal. Other supported platform families retain their native package-manager syntax behind `lib/cc-packages.sh`.

### Kernel Management Architecture

`lib/cc-kernel.sh` is the single kernel inspection and classification layer.
On Linux it combines versioned `/boot/vmlinuz-*` artifacts with exact installed
`linux-image-*` package releases, then orders releases with GNU `sort -V` under
the C locale. The running release is always protected, followed by the newest
`KEEP_COUNT` additional releases. List and cleanup commands consume the same
protected and candidate sets.

Cleanup mutation is currently supported only for the Debian-family package
adapter. A version is eligible only when exactly one installed image package is
identified and, when its boot artifact exists, exactly one matching package
owner is reported. Ambiguous or missing ownership retains the kernel. Purge,
autoremove, and clean operations remain behind `lib/cc-packages.sh`.

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
~/.captaincronos/reports/
```

Reports represent timestamped observations.

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

### Assets
Current lifecycle state is stored under:

```text
~/.captaincronos/assets/
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

### Release Workflow
`cc release check` validates the repository, scripts, documentation lint, and working tree before release activity.

## Design Rules

- Commands should be small and composable.
- Long workflows should orchestrate existing commands instead of duplicating logic.
- Read-only commands should remain separate from destructive workflows.
- Reports and assets should remain separate.
- Every command should expose metadata for registry and documentation generation.
