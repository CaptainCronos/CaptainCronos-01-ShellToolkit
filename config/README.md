# Toolkit Configuration

## Program Interfaces

Preferred command-line program choices are defined in `config/programs.conf`
and resolved by `lib/cc-programs.sh`. The file is intentionally limited to
executable names; command arguments, pipelines, privilege escalation, and shell
logic belong in libraries.

Inspect the configured capability interfaces with:

```bash
cc programs
cc programs check
cc programs show pkg-manager
```

Program reporting is read-only. Missing programs are reported and are never
installed automatically.

System package behavior is implemented in `lib/cc-packages.sh`. On Debian-family
systems it resolves package operations, repository queries, and the installed
package database through `pkg-manager`, `pkg-query`, and `pkg-database`.
Configuration contains executable choices only; dry-run behavior, arguments,
and privilege escalation remain in the library.

## User Configuration

Toolkit configuration lives in:

```text
~/.captaincronos/config
```

Use `cc config show`, `cc config get KEY`, and `cc config set KEY VALUE` to inspect or update settings.

## Update Settings

Developer ecosystem updates are disabled in the full maintenance workflow by default:

```bash
DEV_UPDATES="no"
```

This keeps `cc system-update` focused on OS and desktop/app package managers while still reporting npm, pipx, pip, cargo, go, and gem status. Set `DEV_UPDATES` only when you want supported developer package managers included in `cc update --apply`:

```bash
cc config set DEV_UPDATES yes
```

Even with config enabled, mutating developer updates still require an explicit `--apply` workflow. Use `cc update dev --dry-run` or `cc update npm --dry-run` for review first.
