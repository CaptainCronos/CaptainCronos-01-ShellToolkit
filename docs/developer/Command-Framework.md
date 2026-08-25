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
4. Discover command modules and their public CLI contracts.
5. Render read-only command or subcommand switch discovery before dependency or command execution.
6. Validate obvious switch, value, subcommand, and positional usage errors.
7. Dispatch valid invocations to the command module.
8. Provide generated help output.

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

The `Purpose` line should be concise because `cc help` uses the shared metadata
registry to generate its command listing. The listing derives one dotted-leader
endpoint from the longest registered command, preserving every command and
description without per-command padding or truncation.

Public switch and subcommand contracts live in `lib/cc-metadata.sh`. This is the
authoritative discovery layer consumed by `tools/cc`, `lib/cc-help.sh`, generated
command references, and contract tests. It records command classification,
usage, positional policy, subcommands and aliases, switch arity, defaults, and
bounded safety descriptions. Command scripts still implement parsing and
behavior; do not duplicate discovery text in a second registry.

`tests/command-switches.sh` protects this boundary. It requires one contract per
registered command, switch discovery for every command and namespace entry,
unique switch rows, source presence for advertised switches, and focused
parser/metadata fixtures for important aliases and value-taking switches. Bash
does not provide reliable general static parser introspection, so this is
deliberately described as focused drift protection rather than a proof for every
possible parser control flow.

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

Cross-subsystem persistent ownership belongs to `cc maintenance`, not to a
report, asset, environment, or repository command. Its `status`, `inventory`,
`retention`, and `cleanup` contexts participate in central switch discovery.
For v1.3, cleanup is a zero-candidate preview and `--apply` is intentionally
absent; adding deletion later requires ownership, recoverability, objective
policy, candidate parity, containment, authorization, and fixture proof.

---

## Discovery Model

Operator discovery proceeds from broad to narrow:

```text
cc help
cc <command> switches
cc <command> <subcommand> switches
```

`switches` is the canonical read-only discovery keyword. The dispatcher handles
it before dependency checking and before command execution, so it cannot fall
through to preview or apply code. Namespace output includes namespace switches,
available subcommands and aliases, and the nested discovery form. Commands with
no command-specific switches say so explicitly.

Top-level `--help` and `-h` remain command-owned to preserve detailed existing
help. Exact nested `--help` and `-h` requests use the contextual renderer where
the underlying namespace did not previously provide narrow help. The word
`help` remains supported where an existing namespace already accepted it.

Before dispatch, known contracts distinguish unknown switches, unknown
subcommands, invalid positionals in declared argument-free contexts, and missing
switch values. Errors render the narrowest relevant context and then preserve
usage status 2. Rendering never converts a failed invocation to success.

Current dispatch behavior:

1. `cc` searches `tools/commands/`.
2. It resolves discovery or validates the registered CLI contract.
3. If a matching command exists and validation succeeds, it executes it.
4. If no command exists, `cc` prints an error and generated global help.

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
