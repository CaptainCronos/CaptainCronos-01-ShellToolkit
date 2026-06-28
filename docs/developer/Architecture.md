# Architecture

Captain Cronos Shell Toolkit is organized as an installable shell environment and engineering framework.

The architecture separates source files, deployable defaults, operating-system baselines, installer logic, shared libraries, command modules, and archived migrations.

---

## Core Flow

```text
User
  |
  v
cc
  |
  v
tools/commands/
  |
  +-- install -> install/install.sh
  +-- update  -> install/update.sh
  +-- verify  -> install/verify.sh
  +-- doctor  -> health checks
  +-- version -> VERSION
```

The `cc` command is the public command front-end. It dispatches subcommands from `tools/commands/`.

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

---

## Command Framework

The `tools/cc` dispatcher should remain small. Command behavior belongs in standalone files under:

```text
tools/commands/
```

Adding a command should not require editing the dispatcher unless command discovery behavior itself changes.

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
