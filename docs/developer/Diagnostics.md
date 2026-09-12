# Debug and Progress Infrastructure

Captain Cronos commands use `lib/cc-diagnostics.sh` for intentional diagnostics
and count-based workflow progress. Commands must not create competing debug
flags, global tracing systems, or private progress implementations.

## Output contract

- Normal human and machine-readable results use stdout.
- Debug diagnostics use stderr and begin with `[CC DEBUG]`.
- Interactive workflow activity uses stderr and begins with `[CC TEST]` or the
  equivalent shared progress prefix.
- Errors use stderr.
- Debug and progress output must never be written to JSON or other structured
  stdout.

## Debug API

Commands parse `--debug` and call `cc_debug_enable`. Libraries inspect the one
framework state with `cc_debug_enabled`; they do not parse command arguments.
Use `cc_debug`, `cc_debug_kv`, `cc_debug_block`, and `cc_debug_result` for
intentional events and captured command results.

Diagnostics should explain the requested semantic operation, resolver or
platform adapter, selected implementation, compatibility/status result, parser
field, and failure propagation when those facts affect the result. Do not dump
the environment or unrelated state.

Keys containing password, token, secret, API-key, authorization, credential, or
private-key terms are redacted by `cc_debug_kv`. Captured failure output passes
through common redaction before emission. Callers must still avoid passing
arbitrary credentials or secret-bearing command lines to diagnostics.

## Progress API

`cc_progress_*` is the canonical count-based progress API. It is stateful
diagnostic infrastructure in `lib/cc-diagnostics.sh`; callers must not
hand-build carriage-return `RUNNING` lines or create competing progress helpers.
Counts describe completed stages, not estimated execution time.

The public contract is:

- `cc_progress_init TITLE TOTAL [MACHINE] [TAG]` initializes a non-empty
  workflow. `TITLE` must be non-empty; `TOTAL` must be a positive decimal
  integer; `MACHINE` is `0` (default) or `1`; and `TAG` defaults to `STATUS`
  and must match `[A-Za-z][A-Za-z0-9_-]*`. It accepts two through four
  arguments. Zero-total workflows are not supported.
- `cc_progress_start LABEL` accepts exactly one non-empty label after a
  successful init. It cannot start another operation while one is active or
  exceed the declared total.
- `cc_progress_finish STATUS` accepts exactly one non-empty status only for an
  active operation. It renders through `cc_status_line_fd` when that helper is
  available.
- `cc_progress_live` and `cc_progress_sequential` report the selected
  presentation mode.
- `cc_progress_cleanup` accepts no arguments and is safe to call repeatedly.
  Call it when abandoning an active workflow so a live terminal is left on a
  clean line.

Invalid calls return `2` without changing progress counters or active state.
After init, `current=completed=active=0`; after start, `current` increases once
and `active=1`; after finish, `completed` increases once and `active=0`. At all
valid points, `completed <= current <= total`. `CC_PROGRESS_INITIALIZED`
distinguishes use before initialization from an initialized workflow with no
completed operations.

When stderr is a terminal, normal selftest uses a live `RUNNING` line followed
by the completed status. Redirected and piped execution retains stable existing
numbered result lines without terminal controls. Child stdout and stderr remain
captured until the harness has completed its canonical result line, so embedded
commands cannot attach to or duplicate that presentation. Machine mode suppresses
normal progress. Debug mode automatically selects sequential `[CC TEST]` lines
instead of live redrawing, including when JSON is requested.

Progress presentation is stderr-owned. Machine-readable stdout must remain
uncontaminated: non-debug machine mode is silent, while debug diagnostics remain
on stderr. Live redraw is terminal-dependent; debug mode always uses sequential
lines. No spinner abstraction is provided because the toolkit has no demonstrated
indeterminate-progress consumer; spinner support is deferred until one exists.

## Selftest

`cc selftest --debug` records the test, subsystem, operation, expected and
actual status, captured stream sizes, and redacted failure output. It returns
the same status and retains the same final summary as normal selftest. Combine
it with `--json` to keep JSON alone on stdout and diagnostics on stderr.

`cc selftest --verbose` reports successful captured-stdout sizes rather than
replaying child presentations, and emits successful stderr as a labeled detail
block. Failed checks retain labeled stdout and stderr after the canonical `FAIL`
line. Focused test scripts therefore keep their useful standalone success
summaries without duplicating the selftest harness result.

Future commands may reuse these APIs, but should only emit events that answer
what is running, which path was selected, and why it passed or failed.
