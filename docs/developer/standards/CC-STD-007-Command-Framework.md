# CC-STD-007 — Command Framework

The command framework defines how user-facing operations are exposed.

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

## Future Plugins

Future plugin commands may live under:

```text
plugins/<plugin-name>/commands/
```

Built-in commands should take precedence over plugin commands if names conflict.
