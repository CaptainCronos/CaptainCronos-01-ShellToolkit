# CC-STD-007 — Command Framework

This document defines how ShellToolkit exposes user-facing operations. It is a
project implementation contract; the Engineering Manual governs broader
architecture policy.

---

## Public Interface

The stable public interface should remain small:

```text
cc
helpme
gitflow
```

Most new operational behavior should be implemented as `cc` subcommands.

---

## Dispatcher

The `tools/cc` script is a dispatcher. It should remain small and generic.

Built-in commands live in:

```text
tools/commands/
```

Each command should be a standalone script with a standard header.

Mutating batch repository workflows under `cc repos` should be dry-run by default and require `--apply`. Push workflows must not force push. The guarded publish workflow is limited to clean repositories on branch `main` and runs `git push origin main`.

---

## Command Discovery

`cc help` should discover commands by scanning `tools/commands/` and reading each command's `Purpose` header.

Adding a command should not require editing the dispatcher unless discovery behavior changes.

---

## Command Naming

Use short, clear names:

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

Avoid vague names such as:

```text
do-stuff
run
misc
```

---

## Plugins

Plugin API 1 does not register commands. The dispatcher searches only
`tools/commands/`; manifests containing command fields are invalid. A later
contract may add bounded command registration, but it must preserve core
namespace precedence and fail closed for plugin/plugin collisions without
sourcing code during registry or help discovery.
