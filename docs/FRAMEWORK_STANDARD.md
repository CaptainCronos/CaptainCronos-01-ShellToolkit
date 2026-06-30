# Captain Cronos Framework Standard

## Purpose

This document defines the implementation standard for the Captain Cronos Shell Toolkit. It is the baseline for commands, plugins, namespaces, installation workflows, documentation, and quality gates.

The framework is designed to be portable across developer workstations, live USB workbench sessions, laptops, servers, and NAS-adjacent environments.

## Framework Principles

1. Commands must be predictable.
2. Metadata must be machine-readable.
3. Destructive actions must require an explicit apply or confirmation path.
4. Existing commands should remain compatible when namespaces are introduced.
5. Host-specific state must live outside the repository.
6. Platform behavior must be based on capabilities, not assumptions.
7. PASS, WARN, and FAIL must have consistent meaning across the toolkit.

## Repository Layout

| Path | Purpose |
|---|---|
| tools/cc | Top-level command dispatcher. |
| tools/commands/ | User-facing command entrypoints. |
| lib/ | Shared framework libraries. |
| plugins/ | Plugin namespaces and implementation files. |
| docs/ | Human-authored documentation. |
| docs/generated/ | Generated command inventory, references, and reports. |
| install/ | Installation and repository verification workflows. |
| bash/ | Managed shell profile, aliases, and functions. |
| baseline/ | Captured baseline shell configuration. |

## Host State Layout

Host-specific state must not be committed to the repository.

Default host state root:

```text
~/.captaincronos/
    hosts/
        <host-id>/
            config
            reports/
            assets/
            cache/
            logs/
            plugins/
```

The Linux hostname is not the same as the Captain Cronos host ID. Host IDs may be initialized from the hostname, but they must be overrideable.

## Command Header Standard

Every file in tools/commands must include the standard metadata header.

Required fields:

| Field | Required | Purpose |
|---|---:|---|
| Script | yes | Command or library name. |
| Version | yes | Command version or reads VERSION. |
| Category | yes | Registry grouping. |
| Requires | yes | Enforced dependency list. |
| Repository | yes | Owning repository. |
| Purpose | yes | Help, registry, and documentation summary. |

Every command must support help and version output.

## Command Behavior Standard

Every command should use strict Bash behavior and shared framework libraries.

Commands that need host identity should use the environment library.
Commands that need platform or capability checks should use the platform library.
Commands that need dependency helpers should use the dependency library.

## Exit Code Standard

| Exit Code | Meaning |
|---:|---|
| 0 | Success. |
| 1 | General command failure or validation failure. |
| 2 | Usage error. |
| 3 | WARN-level health state when command policy requires nonzero. |
| 127 | Missing required dependency. |

## PASS / WARN / FAIL Standard

| Status | Meaning | Action |
|---|---|---|
| PASS | Correct and no action required. | Continue. |
| WARN | Functional but should be corrected. | Report and optionally repair. |
| FAIL | Required condition is not met. | Stop or require repair. |

Examples:

| Check | PASS | WARN | FAIL |
|---|---|---|---|
| PATH entry | Present exactly once | Duplicate or directory missing | Missing from PATH |
| Dependency | Installed | Optional missing | Required missing |
| Working tree | Clean | Dirty during report-only command | Dirty during release gate |
| Command audit | Fully compliant | Legacy or compatibility issue | Syntax or required behavior failure |

## Dry Run and Apply Standard

Commands that modify host state must clearly separate reporting from changes.

Preferred flags:

- --apply
- --dry-run
- --fix

Rules:

1. Report what will change before changing it.
2. Use --apply for planned modifications.
3. Use --fix for targeted repair actions.
4. Do not silently modify system state from report-only commands.

## Logging Standard

Standard prefixes:

```text
[CC] normal operation
[CC WARN] warning
[CC ERROR] error
```

Output should be readable in a terminal and suitable for copy/paste into troubleshooting notes.

## Namespace Standard

New feature areas should be implemented as namespaces instead of adding many flat commands.

Preferred top-level namespaces:

```text
cc env
cc storage
cc repo
cc asset
cc maintenance
cc bitcoin
cc docs
cc plugin
```

Compatibility wrappers may remain during migration.

## Dependency Standard

The Requires header is the source of truth for command dependencies. The dispatcher must enforce required dependencies before running commands.

Dependency reporting commands:

```text
cc deps core
cc deps storage
cc deps docs
cc deps optional
cc deps command COMMAND
```

Required dependencies are blockers. Optional dependencies should be reported as warnings or recommendations only.

## Platform and Capability Standard

Commands must avoid assuming a platform when capability detection is possible.

Operating system detection tells the framework what family it is on. Capability detection tells commands what they can safely do.

## Environment Standard

The environment namespace is responsible for host identity, shell files, and PATH health.

Canonical commands:

```text
cc env
cc env path
cc env path --fix
cc env shell
cc env host
cc env doctor
```

PATH policy:

| Condition | Result |
|---|---|
| Required path present exactly once | PASS |
| Required path duplicated | WARN |
| Required path missing from PATH | FAIL |
| Required directory missing | WARN |

Required PATH entries:

```text
~/bin
~/.local/bin
```

## Installation Standard

Installation is the first-time enrollment path.

Install must:

1. Verify dependencies before changing files.
2. Verify repository structure.
3. Verify shell syntax.
4. Create backups before replacing shell files.
5. Install the cc launcher.
6. Report PATH health.
7. Provide post-install verification commands.

Ongoing maintenance should prefer cc update rather than repeatedly running install manually.

## Workbench Standard

The workbench profile is for live USB drive qualification.

Canonical command:

```text
cc workbench prepare --apply
```

Workbench setup should verify network, clone or update the toolkit repository, install the toolkit, initialize the host identity as workbench, run self-test unless disabled, and display drive qualification next steps.

## Storage Standard

The storage namespace is the canonical storage interface.

Canonical commands:

```text
cc storage inventory
cc storage drives
cc storage smart DEVICE
cc storage test DEVICE ACTION
cc storage report DEVICE
cc storage qualify DEVICE
cc storage burnin DEVICE
cc storage workbench
cc storage deps
cc storage status
```

Compatibility commands may remain, including drive-inventory, drive-smart, drive-test, drive-report, drive-qualify, and drive-burnin.

Storage commands must be non-destructive unless an explicit destructive path is introduced with strong confirmation.

## Asset Standard

Asset records are host-scoped and should live below the host asset directory.

Asset lifecycle states should include at minimum:

```text
new
inventory
testing
qualified
production
watch
failed
retired
```

Drive qualification should eventually update asset records automatically.

## Quality Gates

Before release or significant commit, run:

```text
cc selftest
cc audit --strict
cc docs lint
cc verify executable
cc release check
```

A release-ready tree must have strict audit clean, executable audit clean, docs lint clean, release check clean, and working tree clean.

## Version Milestones

### 1.2.x

Framework construction and quality gates.

### 1.3.x

Framework complete:

- Stable namespaces
- Storage plugin
- Environment plugin
- Asset database
- Installation framework
- Workbench support

### 1.4.x

Infrastructure integrations:

- TrueNAS read-only reporting
- ZFS status
- SMART history
- Backup verification
- Storage lifecycle automation

### 2.0

Multi-host management:

- Remote host inventory
- Fleet reporting
- Remote execution
- Cross-host asset lifecycle

## New Command Checklist

Before a new command is considered complete:

- Standard metadata header present.
- Help output works.
- Version output works.
- Required dependencies listed in Requires.
- Command is executable.
- Bash syntax passes.
- Strict audit passes.
- Documentation lint passes.
- Namespace placement considered.
- Dry-run or apply behavior used if command modifies state.
- PASS, WARN, and FAIL semantics used consistently.
