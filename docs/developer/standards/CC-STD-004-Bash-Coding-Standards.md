# CC-STD-004 — Bash Coding Standards

The Engineering Manual's `07-Standards/Bash.md` is authoritative for general
Bash safety, style, failure behavior, dependencies, and validation. This page
adds ShellToolkit-specific conventions for code in this repository.

---

## ShellToolkit Execution Context

Executable scripts should start with:

```bash
set -euo pipefail
```

Use exceptions only when documented. Sourced ShellToolkit libraries must not
unexpectedly alter the caller's shell options.

---

ShellToolkit code must remain usable in its documented rescue and live-USB
environments.

## Toolkit Conventions

- Prefer functions for repeated logic.
- Avoid aliases inside scripts.
- Prefer shared libraries over duplicated command behavior.
- Use `TOOLKIT_ROOT` for toolkit files and `CURRENT_REPO` for caller-repository
  behavior.

---

## Safety

- Use `--dry-run` for installers and destructive operations where practical.
- Do not modify tracked repository files during normal install/update use.

---

## Output

Use shared logging helpers from `lib/cc-common.sh` where practical:

```bash
cc_log
cc_warn
cc_error
cc_banner
cc_section
cc_subsection
```

New framework commands must use `cc_section` or `cc_subsection` for
user-visible title/underline pairs. Use `cc_section_fd` or
`cc_subsection_fd` when structural output must go to a non-stdout file
descriptor. Do not maintain hard-coded underline strings in commands.

---

## Dependencies

ShellToolkit command `Requires` metadata and the shared dependency layer define
how required executables and semantic capabilities are checked.
