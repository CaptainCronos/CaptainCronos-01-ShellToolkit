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
- `cc-config.sh` — toolkit configuration helpers
- `cc-programs.sh` — configured command-line capability resolution
- `cc-packages.sh` — semantic, platform-aware system package operations
- `cc-network.sh` — semantic, platform-aware network-state inspection
- `cc-services.sh` — scoped service lifecycle, timer, and system-log operations
- `cc-metadata.sh` — command metadata and registry helpers
- `cc-assets.sh` — local asset database helpers
- `cc-prompt-engine.sh` — internal prompt template discovery, rendering, and formatting helpers

### Configuration
User configuration is stored under:

```text
~/.captaincronos/config
```

Use `cc config` to view or modify it.

### Update Architecture
Maintenance updates are split into three surfaces:

- System package operations: semantic update, upgrade, install, removal, query, and database interfaces resolved through the platform and Program Management layers.
- Desktop/app package managers: snap, flatpak, and direct desktop app refreshes already managed by `cc system-update`.
- Developer ecosystem package managers: npm, pipx, pip, cargo, go, and gem.

`cc system-update` owns system and desktop/app updates. It detects and reports developer ecosystem package managers, but does not update them. This protects project toolchains, global CLIs, language-specific package state, and user development environments from broad workstation maintenance runs.

On Debian-family systems, toolkit automation uses the configured `apt-get` interface for package operations, `apt-cache` for repository queries, and `dpkg` for the installed-package database. Interactive administrators may still use `apt` directly at a terminal. Other supported platform families retain their native package-manager syntax behind `lib/cc-packages.sh`.

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

### Reports
Historical reports are stored under:

```text
~/.captaincronos/reports/
```

Reports represent timestamped observations.

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
