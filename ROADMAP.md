# Captain Cronos Shell Toolkit Roadmap

Current milestone: **v1.0.0-alpha1 — Blackbeard**

The Shell Toolkit has moved from a personal Bash collection into an engineered, installable toolkit with versioning, verification, baseline capture, defaults, and GitHub-backed development workflow.

---

## Phase 1 — Engineering Foundation

Status: **Complete**

Completed items:

- Repository structure standardized.
- `VERSION` file created.
- `manifest.yml` created.
- `lib/cc-common.sh` created.
- `baseline/ubuntu-26.04/` created.
- `defaults/v1/` created.
- `install/verify.sh` created.
- `install/create-baseline.sh` created.
- `install/promote-defaults.sh` created.
- `install/update.sh` created.
- `tools/cc-version` created.
- `tools/cc-doctor` created.
- `lstree` updated to v2 behavior.
- `helpme` updated with engineering sections.
- Migration scripts archived.

---

## Phase 2 — Installer and Command Framework

Status: **In Progress**

Purpose:

Build the Shell Toolkit into a self-maintaining package-style system with a single command front-end, intelligent installation, verification, and upgrade paths.

### Phase 2.1 — Intelligent Installer

Status: **In Progress**

Goals:

- Support `--help` and `--version`.
- Support `--dry-run`.
- Support `--no-backup`.
- Support `--no-baseline`.
- Support `--no-bashrc`.
- Verify repository structure before install.
- Verify Bash syntax before install.
- Capture baseline when needed.
- Back up existing user shell files.
- Install `bash/bashrc`, `bash/bash_aliases`, and `bash/bash_functions`.
- Verify installed files after install.
- Print final install report.
- Detect first install.
- Detect upgrade.
- Detect repair.
- Support rollback if installation fails.

### Phase 2.2 — Unified `cc` Command

Status: **Started**

Goals:

Create a single command front-end:

```bash
cc install
cc update
cc verify
cc doctor
cc version
cc baseline
cc defaults
cc help
```

The `cc` command should dispatch to the existing scripts without duplicating their logic.

### Phase 2.3 — Expanded `cc-doctor`

Status: **Planned**

Goals:

- Check repository structure.
- Check required files.
- Check executable bits.
- Check Bash syntax.
- Check Git status.
- Check origin remote.
- Check installed shell files.
- Check baseline/default files.
- Check dependencies.
- Print a clear pass/warn/fail report.

### Phase 2.4 — Manifest-Driven Installation

Status: **Planned**

Goals:

Move installation source and destination mappings into `manifest.yml` so installer logic is not hardcoded.

Future example:

```yaml
install:
  shell_files:
    - source: bash/bashrc
      destination: ~/.bashrc
    - source: bash/bash_aliases
      destination: ~/.bash_aliases
    - source: bash/bash_functions
      destination: ~/.bash_functions
```

### Phase 2.5 — Self-Documentation

Status: **Planned**

Goals:

- Generate command listings from metadata.
- Keep `helpme`, docs, and command index synchronized.
- Generate future `docs/user/Commands.md` automatically.

---

## Phase 3 — Toolkit Expansion

Status: **Planned**

Purpose:

Begin adding user-facing tools after the installer and command framework are stable.

Candidate categories:

- Filesystem tools
- Backup tools
- Git tools
- Network diagnostics
- System diagnostics
- Package/dependency helpers
- Documentation generators

---

## Phase 4 — Plugin System

Status: **Planned**

Purpose:

Allow optional toolkit modules to be installed independently.

Candidate plugin areas:

- Git
- Network
- Server administration
- TrueNAS
- Bitcoin node operations
- Desktop repair
- Rescue USB utilities

---

## Phase 5 — Release Framework

Status: **Planned**

Goals:

- Version bump workflow.
- Changelog generation.
- Release notes.
- Git tags.
- Archive/package generation.
- Reproducible release artifacts.
