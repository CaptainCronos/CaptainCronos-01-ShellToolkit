# Captain Cronos Shell Toolkit — Codex Authority

## Purpose

Codex is authorized to perform substantial autonomous development work inside
this repository. The objective is to minimize unnecessary maintainer approvals
while protecting the live host, data, services, credentials, and published Git
history.

## Normal Development Authority

Codex may without additional maintainer approval:

- Read the complete repository.
- Read host state required for diagnostics and implementation.
- Create and switch local feature branches.
- Create, edit, rename, and delete repository files required by the approved task.
- Run repository tooling and targeted tests.
- Run Bash syntax checks, ShellCheck, fixture tests, documentation checks,
  `git diff --check`, and similar development verification.
- Create and use temporary files and disposable test environments.
- Inspect Git history, status, branches, tags, and remotes.
- Use dry-run and preview modes.
- Access public technical documentation when network access is available.

## Repository Write Boundary

Normal writes are confined to:

    /home/captaincronos/GitHub/CaptainCronos-01-ShellToolkit

Reading outside the repository is permitted when necessary.

Writing outside the repository requires explicit maintainer authorization,
except for temporary/disposable locations created by repository tests.

## Protected Operations

STOP and request explicit maintainer approval before:

- committing
- pushing
- merging to main
- creating or deleting Git tags
- creating releases
- force pushing
- rebasing or rewriting published history
- deleting branches other than an explicitly approved completed feature branch
- changing VERSION, release maturity, or release dates
- installing or removing system packages
- enabling, disabling, starting, stopping, restarting, or modifying live services
- modifying firewall, routing, DNS, or live network configuration
- modifying mounts, partitions, filesystems, RAID, ZFS pools, datasets, or vdevs
- rebooting or shutting down the host
- writing under /etc, /boot, /usr, /var or other system-owned locations
- changing user/group membership or host permissions
- reading or modifying credentials, private keys, wallet material, secrets,
  authentication tokens, or password stores
- destructive drive testing
- destructive container operations
- changing live Bitcoin, TrueNAS, backup, or production-service state

## Git Safety

Feature development belongs on feature branches.

Do not perform feature development directly on main.

Never run the following without explicit maintainer authorization:

    git push --force
    git push --force-with-lease
    git reset --hard
    git clean -fd
    git clean -fdx

Never discard an existing dirty working tree unless the maintainer explicitly
authorizes the exact cleanup.

## Mutation Testing

Host-mutating toolkit functionality should normally be tested with:

- fixtures
- mocks
- disposable HOME directories
- temporary directories
- dry-run or preview modes

Do not test mutation against the maintainer's live system merely because host
read access is available.

Running an `--apply` operation against the live host requires explicit
maintainer authorization.

## Verification

During active development prefer targeted verification:

- affected component tests
- regression tests for touched infrastructure
- bash -n
- ShellCheck
- git diff --check

Run `cc selftest` at meaningful component checkpoints.

Reserve heavier framework/release verification for appropriate framework or
release checkpoints rather than repeatedly running it after small edits.

## Scope Control

Implement only the approved component or task.

Do not silently expand into adjacent roadmap components.

Do not redesign established subsystems merely because another design is
possible. If the approved task genuinely requires an architectural change,
report the conflict before expanding scope.

## Maintainer Gate

Before requesting permission to commit, report:

- files created
- files modified or deleted
- behavior added or changed
- targeted test results
- regression results
- selftest result when applicable
- known limitations
- recommended commit message

The maintainer owns commit, merge, push, tag, release, and live-host mutation
decisions.
