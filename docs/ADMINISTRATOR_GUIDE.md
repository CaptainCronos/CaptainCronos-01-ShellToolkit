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
