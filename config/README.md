# Toolkit Configuration

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
