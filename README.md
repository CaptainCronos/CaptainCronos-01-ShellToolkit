# Captain Cronos Shell Toolkit

**Current milestone:** `v1.0.0-alpha1` — **Blackbeard**

Captain Cronos Shell Toolkit is the reference implementation of the Captain Cronos engineering framework. It provides a standardized Linux shell environment, reusable Bash functions, installer tooling, baseline capture, release defaults, and a growing command framework built around the `cc` command.

The project began as a personal Bash configuration and has evolved into a documented, versioned, installable toolkit intended to be reusable across Linux workstations, rescue environments, servers, and future Captain Cronos projects.

---

## Goals

- Provide a reliable shell environment that can be rebuilt from source.
- Keep aliases, functions, installer logic, documentation, and defaults under Git control.
- Separate operating-system baselines from Captain Cronos defaults.
- Maintain rollback paths through timestamped backups.
- Standardize script headers, versioning, repository layout, and release process.
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
cc repo
cc doctor
helpme engineering
lstree --depth 2 .
```

---

## Current Command Interface

The long-term command front-end is:

```bash
cc <command> [options]
```

Initial commands include:

```bash
cc version
cc repo
cc doctor
cc verify
cc install
cc update
cc baseline
cc defaults
cc help
```

The command framework is being migrated toward `tools/commands/`, where each command is a standalone script discovered by the `cc` dispatcher.

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
