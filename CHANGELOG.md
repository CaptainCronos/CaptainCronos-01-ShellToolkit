# Changelog

All notable changes to Captain Cronos Shell Toolkit will be documented in this file.

The format follows a simple milestone-based structure until the project reaches stable release status.

---

## Unreleased

### Added

- Fixture-based mutation-contract coverage for installer, toolkit-update,
  system-update, full update orchestration, and monthly-health preview paths.
- Semantic in-memory kernel health snapshots with stable finding codes for diagnostic consumers.
- Kernel PASS/WARN/FAIL integration in `cc doctor` and a detailed kernel section in `cc monthly-health`.
- Kernel integration fixtures covering diagnostic propagation, maintenance advisories, reduced platforms, and consumer isolation from CLI output.
- Read-only `cc kernel platform` environment and operation-support reporting.
- Debian, RPM, Arch, openSUSE, unknown-Linux, and non-Linux kernel package-family classification.
- Evidence-based initramfs-tools, dracut, and mkinitcpio provider detection with ambiguity reporting.
- Separate EFI filesystem-presence and EFI runtime-state inspection.
- Read-only `cc kernel artifacts` package/artifact correlation and `cc kernel health` diagnostics.
- Filesystem-aware `/boot` consumption, EFI capacity, and bootloader-environment inspection.
- Fixture coverage for mount boundaries, artifact consistency, health severity, unusual filenames, and symlink safety.
- Kernel management namespace with status, list, running, cleanup, and dependency actions.
- Shared kernel discovery, ordering, protection, candidate, package ownership, reboot-state, and platform helpers.
- Fixture-based kernel safety tests covering dry-run and mocked apply behavior.
- Semantic, platform-aware system package operations in `lib/cc-packages.sh`.
- Focused package-management capability, query, dry-run, and platform tests.
- Semantic, platform-aware network inspection in `lib/cc-network.sh`.
- Focused network capability, helper, and non-Linux abstraction tests.
- Semantic, explicitly scoped service and system-log operations in `lib/cc-services.sh`.
- Focused service state, scope, dry-run, journal, and non-systemd tests.
- Semantic file-download and HTTP request operations in `lib/cc-http.sh`.
- Focused local HTTP tests for redirects, failures, output, TLS defaults, and secret-safe dry runs.
- Semantic JSON/YAML operations and compatibility checks in `lib/cc-data.sh`.
- Focused structured-data validation, query, compatibility, and injection-safety tests.
- Program Management System with data-only defaults in `config/programs.conf`.
- Capability-oriented program resolution and validation in `lib/cc-programs.sh`.
- Read-only `cc programs`, `cc programs check`, and `cc programs show` commands.
- Public `cc prompt` menu backed by dynamically discovered templates under `templates/prompts/`.
- Interactive prompt collection with previous, next, edit, cancel, preview, and generate flow.
- Prompt clipboard copy helpers for supported host clipboard tools.
- Internal Prompt Engine foundation for dynamic `cc prompt` workflows.
- Metadata-discovered prompt templates for feature, framework, bugfix, docs, workflow, and architecture prompts.
- Required prompt menu metadata for title, description, category, and tags.
- Prompt Engine validation in `install/verify.sh` and `cc selftest`.

### Changed

- `cc install`, the full installer, `cc toolkit-update`, and `cc system-update`
  now default to zero-write preview and require explicit `--apply` for mutation.
- Toolkit dry-run now inspects only local Git state instead of fetching remote
  refs, and the update orchestrator propagates toolkit preview failures.
- System-update creates its persistent log only during apply, rejects unknown or
  conflicting mode options, and propagates mocked package/app failures nonzero.
- Routine system updates no longer rewrite GRUB configuration or automatically
  replace Firefox/Thunderbird from remote tar archives; both behaviors are
  deferred for RC safety review.
- Doctor now delegates reboot, boot artifact, platform, and kernel severity decisions to `lib/cc-kernel.sh`.
- Monthly health now separates kernel health findings from cleanup and reboot maintenance opportunities.
- Monthly health reuses one transient kernel snapshot and suppresses the duplicate kernel scan in its embedded doctor run.
- Kernel findings now include stable codes while retaining PASS/WARN/FAIL severity and human-readable messages.
- Kernel cleanup support now requires the implemented Debian adapter, not merely an `apt-get` executable on Linux.
- Kernel dependency reporting now distinguishes provider evidence from mutation support.
- Non-Linux bootloader inspection no longer misidentifies a generic `/boot/loader` directory as systemd-boot.
- Kernel status now distinguishes the filesystem containing `/boot`, actual `/boot` directory consumption, and EFI filesystem utilization.
- Kernel discovery now uses NUL-delimited filenames and rejects releases that cannot be represented safely.
- Kernel cleanup now consumes the shared kernel library and retains `cc kernel-cleanup` as a compatibility entry point.
- Kernel discovery now combines `/boot` artifacts with exact installed kernel-image packages.
- Debian-family cleanup relies on package lifecycle hooks instead of invoking `update-grub` universally.
- Dependency-group reporting now checks every declared dependency rather than only the first line.
- Debian-family automation now resolves `apt-get`, `apt-cache`, and `dpkg` through the Program Management System.
- System update, kernel cleanup, dependency previews, and baseline package capture now use shared package semantics.
- Linux interface, route, listener, and connection inspection now resolves the configured `ip` and `ss` capabilities.
- Monthly health and workbench network checks now use shared semantic network helpers.
- Systemd service and journal consumers now resolve `service-manager` and `system-log` capabilities.
- Monthly health and its optional user timer now use scoped semantic service operations.
- File downloads now resolve `download`, while API-style GET/HEAD requests resolve `http-api`.
- Program reporting now distinguishes missing programs from incompatible interfaces.
- Asset and drive YAML processing now uses the compatible configured YAML capability.
- Prompt and selftest JSON output now uses semantic JSON generation.
- YAML is required by active asset workflows; JSON remains optional.

### Removed

- Automatic CLI Safe Boot refresh and direct Firefox/Thunderbird archive
  replacement from the routine system-update path.

- Verbose kernel cleanup package-list output from monthly-health; semantic candidate counts remain as maintenance information.
- Nala and Aptitude selection and fallback paths from active system package automation.
- Linux `netstat` fallback and independent `ip`/`nmcli` selection from active network automation.
- Direct `systemctl` and `journalctl` execution from higher-level toolkit commands.
- Direct HTTP client execution from active higher-level toolkit commands.
- Awk-based YAML parsing and predictable YAML mutation temporary filenames.

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
