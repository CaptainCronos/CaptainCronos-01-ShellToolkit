# Captain Cronos Shell Toolkit Administrator Guide

## Purpose
This guide is the primary operational reference for installing, configuring, maintaining, and updating the toolkit.

## Installation
- Clone the repository.
- Run `cc install`.
- Verify with `cc version` and `cc doctor`.

## Configuration
Use `cc config` to review and modify toolkit settings.

## Daily Operations
- `cc update`
- `cc doctor`
- `cc repos status`
- `cc release check`

## Update Operations
`cc system-update` is the OS and desktop application update path. It keeps apt/nala/aptitude, snap, flatpak, direct desktop app refreshes, and the CLI Safe Boot refresh separate from developer ecosystem package managers.

Developer package managers are intentionally report-only during normal system updates because they can change project build tools, language runtimes, global CLIs, user environments, or workstation-specific workflows. Normal `cc system-update` reports npm, pipx, pip, cargo, go, and gem as installed or not installed, shows whether update application is enabled, and prints the dry-run command to review.

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

## Storage Workflow
1. `cc drive-report`
2. `cc drive-qualify`
3. `cc asset inventory drives`
4. `cc drive-burnin` (framework)

## Documentation
- `cc docs inventory`
- `cc docs build --apply`
- `cc docs lint`

## Releases
Run `cc release check` before every tagged release.

## Backups
Preserve both ~/.captaincronos/assets and ~/.captaincronos/reports as part of system backups.
