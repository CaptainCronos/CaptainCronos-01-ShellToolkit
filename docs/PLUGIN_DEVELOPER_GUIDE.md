# Captain Cronos Plugin Developer Guide

## Purpose
This guide defines the standards for adding new commands and plugin functionality to the toolkit.

## Command Location
Core and plugin-facing commands currently live in:

```text
tools/commands/
```

Future plugin implementations may also use:

```text
plugins/<plugin-name>/
```

## Required Command Header
Every command should begin with this metadata block:

```bash
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : command-name
# Version     : reads VERSION or semantic-version
# Category    : Core|Repository|Storage|Maintenance|Documentation|Diagnostics|Engineering
# Requires    : bash git smartctl awk sed grep
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Short command purpose.
# ==============================================================================
```

## Required Behaviors
Each command should support:

```bash
cc command --help
cc command --version
```

## Registry Integration
The command registry reads metadata from command headers. Use:

```bash
cc registry
cc registry markdown
cc docs inventory
```

to confirm the command appears correctly.

## Documentation Integration
After adding or changing commands, run:

```bash
cc docs lint
cc docs build --apply
```

## Testing Checklist
Before committing a new command:

```bash
bash -n tools/commands/<command>
cc <command> --help
cc <command> --version
cc registry
cc docs lint
cc release check
```

## Coding Standards
- Use `set -euo pipefail`.
- Source `cc-common.sh` for shared logging and banner behavior.
- Keep destructive behavior behind explicit confirmation.
- Prefer orchestration over duplicated logic.
- Keep generated reports and current assets separate.

## Versioning
Use semantic-style prerelease versions during active development:

```text
1.0.0-alpha1
1.1.0-alpha1
0.1.0-placeholder
```

Use `reads VERSION` when the command should track the toolkit version instead of having its own version.
