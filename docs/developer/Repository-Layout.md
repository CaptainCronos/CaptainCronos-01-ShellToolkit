# Repository Layout

This document defines the expected layout for Captain Cronos Shell Toolkit.

---

## Top-Level Layout

```text
CaptainCronos-01-ShellToolkit/
├── VERSION
├── manifest.yml
├── README.md
├── ROADMAP.md
├── CHANGELOG.md
├── LICENSE
├── bash/
├── baseline/
├── defaults/
├── docs/
├── install/
├── lib/
├── tools/
├── tests/
├── archive/
├── assets/
├── config/
├── examples/
├── plugins/
├── releases/
└── templates/
```

After Milestone M2, this top-level layout should be considered stable.

---

## Directory Purpose

| Directory | Purpose |
|---|---|
| `bash/` | Active source shell files. |
| `baseline/` | Operating-system baseline/reference files. |
| `defaults/` | Approved deployable Captain Cronos defaults. |
| `docs/` | User and developer documentation. |
| `install/` | Install, update, baseline, defaults, and verification scripts. |
| `lib/` | Shared shell libraries. |
| `tools/` | Command front-end and developer utilities. |
| `tools/commands/` | Built-in `cc` command modules. |
| `archive/` | Archived migrations and deprecated material. |
| `assets/` | Images and static assets. |
| `config/` | Project configuration. |
| `examples/` | Example files and usage patterns. |
| `plugins/` | Future optional modules. |
| `releases/` | Release artifacts or release notes. |
| `templates/` | Reusable templates. |
| `tests/` | Future test scripts and fixtures. |

---

## Layout Rules

1. Do not create new top-level directories without roadmap approval.
2. Put user-facing shell sources under `bash/`.
3. Put installation logic under `install/`.
4. Put shared reusable functions under `lib/`.
5. Put `cc` subcommands under `tools/commands/`.
6. Put one-time migrations under `archive/migrations/` after use.
7. Keep documentation near the audience: `docs/user/` or `docs/developer/`.

---

## Repository Cleanliness

The repository should not become modified simply because the installer ran.

Installer behavior should write to user locations such as:

```text
~/.bashrc
~/.bash_aliases
~/.bash_functions
~/bin/cc
~/.captaincronos/backups/
```

Installer behavior should not change tracked repository permissions or content unless explicitly performing a development operation.
