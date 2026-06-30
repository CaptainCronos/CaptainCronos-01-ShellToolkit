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

### Configuration
User configuration is stored under:

```text
~/.captaincronos/config
```

Use `cc config` to view or modify it.

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
