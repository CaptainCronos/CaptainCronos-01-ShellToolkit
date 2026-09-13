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
cc_info
cc_warn
cc_error
cc_banner
cc_section
cc_subsection
cc_divider
cc_table_header
```

Runtime presentation messages have explicit stream ownership: `cc_log` retains
its established `[CC] message` stdout contract; `cc_info` writes `[CC INFO]
message` to stdout; and `cc_warn` / `cc_error` write `[CC WARN] message` /
`[CC ERROR] message` to stderr. Use `cc_info_fd`, `cc_warn_fd`, or
`cc_error_fd` only when an already-open alternate descriptor is genuinely
required. Their exact two-argument contract is `FD MESSAGE`; non-numeric,
unopened, or otherwise invalid calls return `2` without output. The prefix is
the only colored portion and follows the shared `NO_COLOR`, `TERM=dumb`, and
`CC_COLOR_MODE` policy.

These helpers are runtime presentation, not debug diagnostics, progress UI, or
persistent records. Use `cc_debug*` for redacted debug diagnostics and
`cc_progress_*` for workflow activity; command-specific operational files and
reports retain their own formats. Bootstrap or deliberately standalone code may
render directly when loading `cc-common.sh` would make dependency direction
unsafe. Interactive prompt UI remains command-owned presentation.

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

For count-based workflows, use the canonical `cc_progress_*` API in
`lib/cc-diagnostics.sh`. Progress presentation belongs on stderr and must never
contaminate machine-readable stdout. Do not hand-build carriage-return
`RUNNING` lines: live redraw is terminal-dependent, debug mode uses sequential
lines, and callers must invoke `cc_progress_cleanup` when abandoning an active
workflow. No spinner API exists; add one only when a real indeterminate-progress
consumer establishes the requirement.

Core human-readable command presentation is ASCII-safe by default. Commands
must not hard-code decorative Unicode glyphs; prefer the shared presentation
helpers for statuses, headings, dividers, tables, and progress. Color capability
is independent of this policy. Machine-readable output must remain
representation-neutral, and normal or redirected `TERM=dumb` output must remain
safe. A future Unicode presentation feature requires a concrete consumer, an
ASCII fallback, and tests for both representations; it must extend the shared
presentation layer rather than individual commands. Locale detection is not
currently required because ASCII is the canonical representation.

---

## Dependencies

ShellToolkit command `Requires` metadata and the shared dependency layer define
how required executables and semantic capabilities are checked.
