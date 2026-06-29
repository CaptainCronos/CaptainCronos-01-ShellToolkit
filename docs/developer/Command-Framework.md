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

1. Locate the repository.
2. Load shared functions.
3. Discover command modules.
4. Dispatch the requested command.
5. Provide generated help output.

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
lib/cc-common.sh
```

Commands should not duplicate common logging, version, or repository-detection logic when shared helpers are available.

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
