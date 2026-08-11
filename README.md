# Captain Cronos Shell Toolkit

**Current milestone:** `v1.3.0-beta1` — **Blackbeard**

Captain Cronos Shell Toolkit is the reference implementation of the Captain Cronos engineering framework. It provides a standardized Linux shell environment, reusable Bash libraries, installer tooling, baseline capture, release defaults, storage workflows, asset tracking, reporting, and a growing command framework built around the `cc` command.

The project began as a personal Bash configuration and has evolved into a documented, versioned, installable toolkit intended to be reusable across Linux workstations, rescue environments, servers, NAS systems, and future Captain Cronos projects.

---

## Goals

- Provide a reliable shell environment that can be rebuilt from source.
- Keep aliases, functions, installer logic, documentation, and defaults under Git control.
- Separate operating-system baselines from Captain Cronos defaults.
- Maintain rollback paths through timestamped backups.
- Standardize script headers, versioning, repository layout, and release process.
- Provide shared framework libraries for commands, reports, storage, YAML, assets, and terminal UI.
- Build a foundation that future Captain Cronos repositories can reuse.

---

## Quick Start

Clone the repository:

```bash
git clone git@github.com:CaptainCronos/CaptainCronos-01-ShellToolkit.git
cd CaptainCronos-01-ShellToolkit
```

Review the installer:

```bash
install/install.sh --help
install/install.sh --dry-run
```

Install:

```bash
install/install.sh
source ~/.bashrc
```

Verify:

```bash
cc version
cc selftest
cc framework verify
cc doctor
cc release check
```

---

## Current Command Interface

The long-term command front-end is:

```bash
cc <command> [options]
```

Core and engineering commands include:

```bash
cc version
cc repo
cc doctor
cc verify
cc selftest
cc framework verify
cc audit --strict
cc release check
cc docs lint
cc install
cc update
cc update dev --dry-run
cc baseline
cc defaults
cc programs
cc programs check
cc help
```

Repository management commands include:

```bash
cc repos status
cc repos push --apply
cc repos publish --apply
```

`cc repos push` skips dirty repositories and repositories without an `origin` remote, reports ahead/behind state, and pushes only branches that are ahead of their origin branch. `cc repos publish --apply` is stricter: it skips dirty repositories, skips non-`main` branches, and runs `git push origin main` for each remaining repository.

Prompt commands include:

```bash
cc prompt
```

`cc prompt` opens the Prompt Engine menu, discovers `templates/prompts/*.prompt`
templates dynamically, reads template metadata, tracks session state while users
navigate with Previous/Back/Next/Cancel, validates answers, previews the
rendered prompt, copies it to the clipboard when a supported clipboard tool is
available, and prints the generated prompt to stdout.

Storage and asset commands include:

```bash
cc storage
cc drives
cc smart
cc drive-report
cc drive-qualify
cc drive-burnin
cc asset
```

Kernel management is available through one safety-first namespace:

```bash
cc kernel status
cc kernel list
cc kernel running
cc kernel cleanup --dry-run
cc kernel deps
```

`cc kernel cleanup` defaults to dry-run, always protects the running kernel,
and protects the newest `KEEP_COUNT` additional kernels. The legacy
`cc kernel-cleanup` command remains a compatibility entry point to the same
implementation. Package removal requires an explicit `--apply`.

Commands live under `tools/commands/`, where each command is a standalone script discovered by the `cc` dispatcher.

Preferred external executables are defined centrally in `config/programs.conf`
and exposed to commands as capabilities through `lib/cc-programs.sh`. Use
`cc programs show pkg-manager`, `cc programs show download`, or
`cc programs show http-api` to inspect an interface without changing the host.

---

## Framework Status

`v1.3.0-beta1` marks the 1.3 framework milestone.

Completed framework areas:

- Shared command dispatcher and `tools/commands/` architecture.
- Shared libraries under `lib/`.
- Engineering validation through `cc selftest`, `cc framework verify`, `cc audit`, `cc verify`, `cc doctor`, and `cc release check`.
- Storage namespace and drive workflows.
- Environment namespace.
- Asset lifecycle and history framework.
- Repository inventory and publishing workflows.
- Shared reporting helpers.
- Capability-backed JSON/YAML helpers with yq compatibility validation.
- Terminal UI helpers for colorized `PASS`, `WARN`, and `FAIL` status output.
- Dotted leader formatting for status lines.

Recommended validation workflow:

```bash
cc selftest
cc framework verify
cc doctor
cc release check
git status --short
```

---

## Repository Layout

```text
CaptainCronos-01-ShellToolkit/
├── VERSION
├── manifest.yml
├── README.md
├── ROADMAP.md
├── CHANGELOG.md
├── bash/
│   ├── bashrc
│   ├── bash_aliases
│   └── bash_functions
├── baseline/
│   └── ubuntu-26.04/
├── defaults/
│   └── v1/
├── docs/
│   ├── developer/
│   └── user/
├── install/
├── lib/
├── tools/
│   └── commands/
└── archive/
```

---

## Shared Libraries

Shared framework code lives under `lib/`.

Current framework libraries include:

```text
lib/cc-common.sh
lib/cc-config.sh
lib/cc-programs.sh
lib/cc-data.sh
lib/cc-yaml.sh
lib/cc-smart.sh
lib/cc-storage.sh
lib/cc-assets.sh
lib/cc-report.sh
lib/cc-prompt-engine.sh
```

Commands should use shared helpers instead of duplicating behavior. In particular, command output should use:

```bash
cc_banner
cc_status_line
cc_log
cc_warn
cc_error
```

Direct `echo "PASS"`, `echo "FAIL"`, and ad hoc status formatting should be avoided in new framework commands.

---

## Baseline, Defaults, and Backups

The project separates three configuration states.

| Layer | Location | Purpose |
|---|---|---|
| Operating-system baseline | `baseline/ubuntu-26.04/` | Pristine shell files captured from the OS skeleton files. |
| Captain Cronos defaults | `defaults/v1/` | Approved deployable toolkit defaults. |
| User backups | `~/.captaincronos/backups/` | Timestamped backups created before install/update. |

This prevents confusion between factory defaults, project defaults, and user-modified files.

---

## Installer

The installer is the supported entry point for deploying the toolkit.

```bash
install/install.sh
```

It performs verification, optional baseline capture, backups, shell file installation, command front-end installation, and post-install validation.

Useful options:

```bash
install/install.sh --dry-run
install/install.sh --no-backup
install/install.sh --no-baseline
install/install.sh --no-bashrc
install/install.sh --no-commands
install/install.sh --version
```

---

## Engineering Standards

Project standards live in:

```text
docs/developer/standards/
```

Current planned standards:

- `CC-STD-001` — Script Header Standard
- `CC-STD-002` — Repository Layout Standard
- `CC-STD-003` — Versioning Standard
- `CC-STD-004` — Bash Coding Standard
- `CC-STD-005` — Documentation Standard
- `CC-STD-006` — Release Process
- `CC-STD-007` — Command Framework

---

## Development Rule

Feature development pauses whenever architecture, installer behavior, versioning, or documentation fall behind the implementation.

The toolkit should remain rebuildable, explainable, and recoverable from the repository alone.
