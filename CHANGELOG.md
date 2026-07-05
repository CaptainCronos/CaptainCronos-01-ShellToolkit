# Changelog

All notable changes to Captain Cronos Shell Toolkit will be documented in this file.

The format follows a simple milestone-based structure until the project reaches stable release status.

---

## Unreleased

### Added

- Internal Prompt Engine foundation for future `cc prompt` commands.
- Metadata-discovered prompt templates for feature, framework, bugfix, docs, workflow, and architecture prompts.
- Prompt Engine validation in `install/verify.sh` and `cc selftest`.

---

## v1.3.0-beta1 — Blackbeard

### Purpose

Framework completion milestone for the Captain Cronos Shell Toolkit.

This release marks the transition from a collection of shell utilities into a structured framework with shared libraries, a command dispatcher, storage workflows, asset tracking, engineering validation, release checks, and a standardized terminal UI.

### Added

- Storage namespace and storage command workflow.
- Environment namespace.
- Asset lifecycle and history framework.
- Shared YAML helper library.
- Shared SMART helper library.
- Shared storage helper library.
- Shared report helper library.
- Drive inventory, SMART, burn-in, qualification, and reporting workflows.
- Report-backed drive qualification output.
- Asset record updates from drive reporting workflows.
- `cc selftest` engineering validation suite.
- `cc framework verify` framework gate.
- `cc release check` pre-release gate.
- Batch `cc repos commit`, `cc repos push`, and `cc repos publish` workflows.
- Shared terminal color helpers.
- Shared status helpers for colorized `PASS`, `WARN`, and `FAIL` output.
- Dotted leader formatting for status lines.
- Library load checks in `cc selftest`.

### Changed

- `drive-report` now uses shared report helpers.
- `drive-qualify` now uses shared report helpers.
- `cc repo` and `cc status` now report the caller repository from `CURRENT_REPO` instead of the toolkit root.
- `cc repos push` now skips dirty repositories, and `cc repos publish` now only pushes clean `main` branches with `git push origin main`.
- Engineering commands now use shared status output:
  - `cc selftest`
  - `cc framework verify`
  - `cc doctor`
  - `cc audit`
  - `cc release check`
  - `cc verify`
- `VERSION` now reports `1.3.0-beta1`.
- README and roadmap now describe the 1.3 framework state.

### Fixed

- Restored executable-bit expectations for framework commands.
- Corrected `cc doctor --full` to invoke `tools/cc` through `bash` without requiring the file itself to be executable.
- Reduced status-output drift across engineering commands.

### Validation

Recommended validation suite:

```bash
cc selftest
cc framework verify
cc doctor
cc release check
cc audit --strict
cc verify executable
git status --short
```

---

## v1.0.0-alpha1 — Blackbeard

### Added

- Standard repository layout.
- `VERSION` file.
- `manifest.yml`.
- `lib/cc-common.sh` shared library.
- `baseline/ubuntu-26.04/` baseline structure.
- `defaults/v1/` defaults structure.
- `install/install.sh` installer framework.
- `install/update.sh` updater.
- `install/verify.sh` repository verifier.
- `install/create-baseline.sh` baseline capture utility.
- `install/promote-defaults.sh` defaults promotion utility.
- `tools/cc` command front-end.
- `tools/cc-version` version helper.
- `tools/cc-doctor` health check helper.
- `tools/commands/version` first command-module migration.
- `helpme` engineering help sections.
- `lstree` v2 repository-aware tree view.
- Migration archive for one-time patch scripts.

### Changed

- Shell files are now managed through the repository rather than copied manually.
- Installer now performs syntax verification before installing.
- Installer now creates timestamped backups.
- Installer now installs `cc` into `~/bin`.
- Command framework is being migrated from a case statement to `tools/commands/` discovery.

### Fixed

- Reduced noisy repository trees by hiding `.git` by default in `lstree`.
- Identified and began correcting executable-bit drift between repository files and installed launchers.

---

## Pre-alpha

### Added

- Initial Bash aliases.
- Initial Bash functions.
- Initial `helpme` function.
- Initial `gitflow` helper.
- Initial repository structure.
