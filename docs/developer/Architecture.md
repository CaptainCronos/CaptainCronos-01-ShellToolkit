# Architecture

Captain Cronos Shell Toolkit is organized as an installable shell environment and engineering framework.

The architecture separates source files, deployable defaults, operating-system baselines, installer logic, shared libraries, command modules, and archived migrations.

---

## Core Flow

```text
User
  |
  v
~/bin/cc
  |
  v
tools/cc
  |
  v
lib/cc-context.sh
  |
  v
tools/commands/
  |
  +-- install -> install active launcher into ~/bin/cc
  +-- update  -> install/update.sh
  +-- verify  -> install/verify.sh
  +-- doctor  -> health checks
  +-- version -> VERSION
```

The `cc` command is the public command front-end. It discovers the active toolkit checkout, initializes runtime context, loads shared libraries, and dispatches subcommands from `tools/commands/`.

---

## Runtime Context

Runtime path and repository discovery is centralized in:

```text
lib/cc-context.sh
```

The context library owns these process-level variables:

```text
TOOLKIT_ROOT   Active Shell Toolkit checkout used for libraries, commands, docs, and VERSION.
CURRENT_REPO   Git repository or directory where the user invoked cc.
PROJECT_ROOT   Backwards-compatible alias for TOOLKIT_ROOT.
```

New toolkit code should use `TOOLKIT_ROOT` for toolkit source files and `CURRENT_REPO` for caller repository behavior. `PROJECT_ROOT` remains exported for older commands, but it must not be used to mean both concepts in new code.

The context library also provides repository helpers such as `cc_repo_name`, `cc_repo_branch`, `cc_repo_remote`, `cc_repo_clean`, and `cc_repo_default_branch`. Commands should use these helpers instead of duplicating Git discovery logic.

---

## Configuration Layers

```text
baseline/ubuntu-26.04/   Operating-system reference files
defaults/v1/             Approved Captain Cronos deployable defaults
bash/                    Active source versions of shell files
~/.captaincronos/        User-side backups and runtime state
```

The baseline represents factory/reference state. Defaults represent approved toolkit state. Backups represent user recovery state.

---

## Installation Model

The installer performs:

1. Repository verification.
2. Bash syntax verification.
3. Baseline capture if needed.
4. Timestamped backups.
5. Shell file installation.
6. `cc` command installation into `~/bin`.
7. Post-install verification.
8. Final report.

Only installed copies should receive executable permissions. Repository files should remain controlled by Git.

The canonical user-level launcher deployment is:

```bash
cc install
```

The full shell-file installer remains available for explicit maintenance through:

```bash
install/install.sh
```

---

## Command Framework

The `tools/cc` dispatcher should remain small. Command behavior belongs in standalone files under:

```text
tools/commands/
```

Adding a command should not require editing the dispatcher unless command discovery behavior itself changes.

---

## Prompt Engine

Prompt rendering infrastructure is internal and lives in:

```text
lib/cc-prompt-engine.sh
templates/prompts/
```

The engine uses the context layer to resolve `TOOLKIT_ROOT`, then discovers
template files from `templates/prompts/*.prompt`. Each template carries
machine-readable metadata headers and line-oriented sections for question
definitions and rendered prompt text.

The engine owns:

- template discovery and metadata catalog output
- interactive question definitions
- `{{variable}}` substitution
- prompt rendering
- output formatting hooks
- clipboard capability metadata for future commands

The public `cc prompt` namespace is intentionally not implemented yet. Future
commands should be thin wrappers over this library.

---

## Future Plugin Model

Future plugin directories may add their own command modules:

```text
plugins/<plugin-name>/commands/
```

The dispatcher can later search built-in commands first, then enabled plugin commands.

---

## Architectural Rule

Top-level directories are part of the project contract. After Milestone M2, new functionality should add files inside existing directories rather than creating new top-level structure unless a roadmap change explicitly approves it.
