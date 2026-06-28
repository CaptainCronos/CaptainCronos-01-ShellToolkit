# CC-STD-004 — Bash Coding Standards

Bash scripts must be readable, defensive, and usable from a rescue environment.

---

## Required Script Settings

Executable scripts should start with:

```bash
set -euo pipefail
```

Use exceptions only when documented.

---

## Style

- Prefer functions for repeated logic.
- Use clear variable names.
- Quote variable expansions.
- Avoid aliases inside scripts.
- Avoid unnecessary external dependencies.
- Keep POSIX-compatible commands where reasonable, but Bash-specific features are allowed.

---

## Safety

- Never overwrite user files without backup unless explicitly requested.
- Use `--dry-run` for installers and destructive operations where practical.
- Validate required files before copying.
- Run `bash -n` during verification.
- Do not modify tracked repository files during normal install/update use.

---

## Output

Use shared logging helpers from `lib/cc-common.sh` where practical:

```bash
cc_log
cc_warn
cc_error
cc_banner
```

---

## Dependencies

Any required external command must be documented and checked before use.
