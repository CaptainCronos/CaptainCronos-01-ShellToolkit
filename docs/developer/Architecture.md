# Architecture

Captain Cronos Shell Toolkit is organized as an installable shell environment and engineering framework.

The architecture separates source files, deployable defaults, operating-system baselines, installer logic, shared libraries, command modules, and archived migrations.

---

## Core Flow

```text
User
  |
  v
~/bin/cc
  |
  v
tools/cc
  |
  v
lib/cc-context.sh
  |
  v
tools/commands/
  |
  +-- install -> preview/apply active launcher installation into ~/bin/cc
  +-- update  -> orchestrate explicitly-modeled toolkit/system/kernel maintenance
  +-- verify  -> install/verify.sh
  +-- doctor  -> health checks
  +-- version -> VERSION
```

The `cc` command is the public command front-end. It discovers the active toolkit checkout, initializes runtime context, loads shared libraries, and dispatches subcommands from `tools/commands/`.

---

## Runtime Context

Runtime path and repository discovery is centralized in:

```text
lib/cc-context.sh
```

The context library owns these process-level variables:

```text
TOOLKIT_ROOT   Active Shell Toolkit checkout used for libraries, commands, docs, and VERSION.
CURRENT_REPO   Git repository or directory where the user invoked cc.
PROJECT_ROOT   Backwards-compatible alias for TOOLKIT_ROOT.
```

New toolkit code should use `TOOLKIT_ROOT` for toolkit source files and `CURRENT_REPO` for caller repository behavior. `PROJECT_ROOT` remains exported for older commands, but it must not be used to mean both concepts in new code.

The context library also provides repository helpers such as `cc_repo_name`, `cc_repo_branch`, `cc_repo_remote`, `cc_repo_clean`, and `cc_repo_default_branch`. Commands should use these helpers instead of duplicating Git discovery logic.

---

## Configuration Layers

```text
baseline/ubuntu-26.04/   Operating-system reference files
defaults/v1/             Approved Captain Cronos deployable defaults
bash/                    Active source versions of shell files
~/.captaincronos/        User-side backups and runtime state
```

The baseline represents factory/reference state. Defaults represent approved toolkit state. Backups represent user recovery state.

---

## Program Management

Preferred external program interfaces are centralized through:

```text
Engineering Manual
        |
        v
config/programs.conf
        |
        v
lib/cc-programs.sh
        |
        v
Captain Cronos commands
```

The configuration contains executable choices only. The library validates the
data-only format and exposes capability-oriented lookup, existence, requirement,
and validation functions. Commands request capabilities such as package manager,
download client, or HTTP API client instead of selecting applications directly.

`cc programs`, `cc programs check`, and `cc programs show CAPABILITY` provide
read-only reporting. They do not install programs or modify host configuration.

System package execution is layered separately in `lib/cc-packages.sh`:

```text
Captain Cronos command
        |
        v
semantic package operation
        |
        +--> platform family
        |
        +--> configured Debian program capability
        |
        v
privileged mutation or unprivileged query
```

Commands call `_cc_pkg_update`, `_cc_pkg_upgrade`, `_cc_pkg_install`,
`_cc_pkg_remove`, and the narrower query/cleanup helpers instead of embedding
package-manager syntax. On Debian-family systems these functions use the
configured `apt-get`, `apt-cache`, and `dpkg` interfaces. Other detected package
families retain their native syntax. Dry-run reporting and `sudo` remain in the
execution library, never in `config/programs.conf`.

Network inspection follows the same capability-oriented boundary through
`lib/cc-network.sh`:

```text
Captain Cronos command
        |
        v
semantic network inspection
        |
        +--> Linux: configured ip / ss capabilities
        |
        +--> FreeBSD: native inspection interfaces
        |
        v
read-only network state
```

`_cc_net_interfaces`, `_cc_net_addresses`, `_cc_net_default_route`,
`_cc_net_routes`, `_cc_net_listeners`, and `_cc_net_connections` keep
machine-oriented command syntax out of higher-level commands. NetworkManager,
DNS, reachability, and scanning interfaces remain separate concerns.

Service and system-log behavior is centralized in `lib/cc-services.sh`:

```text
Captain Cronos command
        |
        v
semantic operation + explicit system/user scope
        |
        +--> systemd: configured systemctl / journalctl
        |
        +--> OpenRC / FreeBSD rc: native service interface
        |
        v
service state, timer state, or read-only logs
```

Service state helpers use `is-active`, `is-enabled`, and `LoadState` semantics
on systemd. Mutation helpers keep dry-run, privilege, and scope behavior in the
library. System log helpers provide no-pager, stable timestamp output with an
explicit record limit where appropriate, without requiring privilege escalation.

HTTP and download behavior is centralized in `lib/cc-http.sh`:

```text
Captain Cronos caller
        |
        +--> file acquisition --> download capability --> wget semantics
        |
        +--> HTTP/API request --> http-api capability --> curl semantics
```

`_cc_download` and `_cc_download_to` preserve file-oriented destination and
retry behavior. `_cc_http_get` and `_cc_http_head` provide redirect-following,
HTTP-error-aware, parseable request output. Dry-run output redacts user-info and
query strings, and TLS verification remains enabled by default.

Structured-data behavior is centralized in `lib/cc-data.sh`:

```text
Captain Cronos caller
        |
        +--> JSON validation/query/output --> json capability --> jq behavior
        |
        +--> YAML validation/query/write --> yaml capability
                                      --> compatible Kislyuk yq behavior
```

`cc_program_status` reports `MISSING` when no executable resolves and
`INCOMPATIBLE` when an executable fails its registered capability probe. Probe
functions follow a reusable capability-naming convention in `cc-programs.sh`.
The YAML probe verifies the Kislyuk identity form and the jq-compatible YAML
serialization syntax actually used; it does not impose an unrelated version
floor.

Query and generation expressions remain separate process arguments. Dynamic keys and values
use `--arg` or `--args`, never shell command construction or `eval`. The legacy
`cc-yaml.sh` API delegates to these helpers so asset callers retain their API
while gaining real YAML parsing and safe atomic writes.

---

## Managed PATH Ownership

`lib/cc-path.sh` owns Captain Cronos PATH policy. The public command
`tools/commands/env` consumes that library for inspection and explicit repair;
the authoritative `bash/bashrc` and promoted default contain the library's
generated managed block. Installer, update, and init code must not emit a
second prepend or guard for `~/bin` or `~/.local/bin`.

The block is placed after environment managers in the authoritative startup
file. It normalizes only the two Captain Cronos managed entries, retaining their
first positions when present and preserving the relative order of unrelated
entries. Missing managed entries are inserted deterministically. Five or more
successive sources and a fresh interactive shell must converge on the same
state with one occurrence of each managed entry.

Repair is authorized only by `cc env path --fix` or its compatible `--apply`
spelling. It recognizes a narrow whitelist of historical conditional `$HOME`,
`${HOME}`, and literal-home prepends plus the exact earlier marked guard shape.
Unknown PATH logic remains byte-preserved and is reported. Mutation uses the
shared temporary-resource lifecycle, same-directory staging, mode preservation,
target identity checks, symlink refusal, content comparison, and atomic rename.
Read-only environment commands create no files or directories.

Because child processes cannot mutate a parent environment, command output must
describe startup repair and current-shell health separately. Reload guidance is
valid only because the installed managed block is source-idempotent.

---

## Installation Model

The installer performs:

1. Repository verification.
2. Bash syntax verification.
3. Baseline capture if needed.
4. Timestamped backups.
5. Shell file installation.
6. `cc` command installation into `~/bin`.
7. Post-install verification.
8. Final report.

Only installed copies should receive executable permissions. Repository files should remain controlled by Git.

The canonical user-level launcher deployment is:

```bash
cc install --apply
```

The full shell-file installer remains available for explicit maintenance through:

```bash
install/install.sh --apply
```

Both commands default to zero-write preview when `--apply` is omitted.

---

## Command Framework

The `tools/cc` dispatcher should remain small. Command behavior belongs in standalone files under:

```text
tools/commands/
```

Adding a command should not require editing the dispatcher unless command discovery behavior itself changes.

---

## Prompt Engine

Prompt rendering infrastructure is internal and lives in:

```text
lib/cc-prompt-engine.sh
templates/prompts/
```

The engine uses the context layer to resolve `TOOLKIT_ROOT`, then discovers
template files from `templates/prompts/*.prompt`. Each template carries
machine-readable metadata headers and line-oriented sections for question
definitions and rendered prompt text.

The engine owns:

- template discovery and metadata catalog output
- prompt menu metadata validation
- interactive question definitions
- reusable session state for the selected template, current question, answers, and cancellation
- shared answer validation for required/optional fields, regexes, choices, ranges, paths, and custom hooks
- `{{variable}}` substitution
- prompt rendering
- output formatting hooks
- clipboard capability helpers for command-layer copy support

The public `cc prompt` command opens a dynamic menu from discovered template
metadata, then reuses this library for questions, rendering, and clipboard
support. It presents numbered menus, breadcrumbs, progress, contextual help,
and graceful Ctrl+C handling. Adding a new `templates/prompts/*.prompt` file
should not require shell code changes.

---

## Future Plugin Model

Future plugin directories may add their own command modules:

```text
plugins/<plugin-name>/commands/
```

The dispatcher can later search built-in commands first, then enabled plugin commands.

---

## Architectural Rule

Top-level directories are part of the project contract. After Milestone M2, new functionality should add files inside existing directories rather than creating new top-level structure unless a roadmap change explicitly approves it.
