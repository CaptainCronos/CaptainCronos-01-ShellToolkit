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
cc_divider
cc_table_header
```

`cc_section` and `cc_subsection` own labeled structural headings and their
underlines. `cc_divider` owns unlabeled structural separation; use
`cc_divider_fd` when that output must go to a non-stdout file descriptor.

`cc_table_header FORMAT HEADER...` owns fixed-width table header and generated
separator rows; use `cc_table_header_fd FD FORMAT HEADER...` for alternate file
descriptors. It preserves the supplied row format and derives one dash per
header-label character, so new framework code must not maintain duplicate
header/separator `printf` calls where this helper applies. Key/value displays
are not tables and remain ordinary command-specific `printf` output. New
framework commands must not hand-build standalone horizontal rules.

Both helpers return `2` without output when required arguments are missing; the
FD variant also returns `2` for a non-numeric or unopened descriptor. `FORMAT`
is trusted toolkit code. Bash `printf` remains authoritative for format and
conversion errors; this helper deliberately does not parse arbitrary formats.

---

## Dependencies

ShellToolkit command `Requires` metadata and the shared dependency layer define
how required executables and semantic capabilities are checked.
