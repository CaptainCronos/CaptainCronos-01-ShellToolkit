# Changelog

All notable changes to Captain Cronos Shell Toolkit will be documented in this file.

The format follows a simple milestone-based structure until the project reaches stable release status.

---

## v2.0.0-alpha — Planned

### Purpose

First documented engineering-framework release.

### Planned

- Complete documentation refresh.
- Freeze repository layout.
- Complete command framework migration.
- Expand `cc doctor`.
- Add release checklist.
- Prepare annotated Git tag.

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
