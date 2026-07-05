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

- System package managers: apt/nala/aptitude and related OS maintenance.
- Desktop/app package managers: snap, flatpak, and direct desktop app refreshes already managed by `cc system-update`.
- Developer ecosystem package managers: npm, pipx, pip, cargo, go, and gem.

`cc system-update` owns system and desktop/app updates. It detects and reports developer ecosystem package managers, but does not update them. This protects project toolchains, global CLIs, language-specific package state, and user development environments from broad workstation maintenance runs.

`cc dev-update` owns developer ecosystem reporting and explicit mutation. It defaults to dry-run/reporting. Mutating developer updates require `--apply`; only package managers with a conservative global update path are applied. Normal `cc update --apply` includes developer updates only when `DEV_UPDATES=yes` is set in toolkit config.

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
definitions, substitutes `{{variables}}`, renders prompt bodies, and applies
output formatting hooks. It does not add a user-facing `cc prompt` command yet.
Future commands such as `cc prompt feature`, `cc prompt bugfix`, and
`cc prompt architecture` should call the shared engine instead of duplicating
template parsing or rendering logic.

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
