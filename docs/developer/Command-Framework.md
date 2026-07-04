# Command Framework

The Captain Cronos command framework defines how operational tools are exposed to the user.

The long-term goal is a small public interface backed by modular command scripts.

---

## Public Interface

The preferred public commands are:

```text
cc
helpme
gitflow
```

Most future operational behavior should be implemented as `cc` subcommands instead of adding more top-level shell commands.

---

## Dispatcher

The dispatcher is:

```text
tools/cc
```

Its job is to:

1. Discover the active Shell Toolkit checkout as `TOOLKIT_ROOT`.
2. Load `lib/cc-context.sh`, `lib/cc-common.sh`, and `lib/cc-deps.sh`.
3. Initialize `TOOLKIT_ROOT`, `CURRENT_REPO`, and the compatibility alias `PROJECT_ROOT`.
4. Discover command modules.
5. Dispatch the requested command.
6. Provide generated help output.

The dispatcher should remain small. It should not contain the full implementation of each command.

---

## Built-In Commands

Built-in command modules live under:

```text
tools/commands/
```

Each command is a standalone Bash script.

Example:

```text
tools/commands/version
tools/commands/doctor
tools/commands/install
tools/commands/update
tools/commands/verify
tools/commands/baseline
tools/commands/defaults
tools/commands/repo
tools/commands/repos
```

---

## Command Metadata

Each command script should include a standard header:

```bash
#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : command-name
# Version     : reads VERSION
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Short command description.
# ==============================================================================
```

The `Purpose` line should be concise because `cc help` may use it for generated command listings.

---

## Command Behavior

Each command should support where practical:

```bash
--help
--version
```

Commands should use shared functions from:

```text
lib/cc-context.sh
lib/cc-common.sh
```

Commands should not duplicate common logging, version, dependency, or repository-detection logic when shared helpers are available. New command code should use `TOOLKIT_ROOT` for toolkit files and `CURRENT_REPO` for caller repository behavior. `PROJECT_ROOT` is retained only as a backwards-compatible alias for older commands and maps to `TOOLKIT_ROOT`.

Batch repository commands should remain conservative. Mutating `cc repos` actions are dry-run by default and require `--apply` before writing to repositories or remotes. `cc repos push` skips dirty repositories, skips repositories without `origin`, reports ahead/behind state, and never force pushes. `cc repos publish` is the strict main-branch release path: after confirming a clean working tree, branch `main`, and an `origin` remote, it runs `git push origin main`.

---

## Discovery Model

Current target behavior:

1. `cc` searches `tools/commands/`.
2. If a matching command exists, it executes it.
3. If no command exists, `cc` prints an error and generated help.

Future plugin behavior:

1. Search built-in commands first.
2. Search enabled plugin command directories next.
3. Prefer built-in commands if names conflict.

---

## Installer Relationship

The installer places the public launcher here:

```text
~/bin/cc
```

The installed launcher executes repository-managed command modules. Installing the launcher must not modify tracked repository files or tracked file modes.

---

## Command Naming Rules

Use short, clear command names:

```text
version
doctor
install
update
verify
baseline
defaults
repo
```

Avoid unclear names:

```text
do-stuff
misc
run
helper
```

---

## Migration Status

The framework is being migrated in stages.

Current direction:

- `tools/cc` becomes the dispatcher.
- existing logic moves into `tools/commands/`.
- help output becomes metadata-driven.
- future plugins can add command modules without changing the dispatcher.

---

## Design Rule

Adding a normal command should mean adding one file under `tools/commands/`, not editing the dispatcher.
