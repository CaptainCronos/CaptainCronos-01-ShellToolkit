# Recent Change Summary

Generated from the canonical CHANGELOG.md release-history authority.

# Changelog

All notable changes to Captain Cronos Shell Toolkit will be documented in this file.

The format follows a simple milestone-based structure until the project reaches stable release status.

---

## Unreleased

### Added

- `cc reports` current-host lifecycle status, detailed inventory, zero-write
  prune preview, and explicitly authorized bounded apply for recognized report
  history.
- Shared report-family metadata and inventory → classification → retention →
  immutable-plan → verified-mutation primitives with deterministic age/size
  accounting, latest protection, and truthful partial-failure results.
- Disposable report lifecycle fixtures covering family policy, permissions,
  unknown/config/asset/evidence protection, exact deletion sets, idempotency,
  host isolation, state changes, and path/symlink confinement.
- Read-only `cc maintenance` persistent-resource status, inventory, retention,
  and disabled-cleanup preview with stable TSV output and contextual switches.
- Shared persistent ownership catalog and bounded accounting for reports, logs,
  assets/history, installer backups, repository bundles, reserved cache,
  plugins, optional monthly-health units, legacy artifacts, and unclassified
  toolkit-home entries.
- Disposable retention fixtures covering classification, accounting, policy,
  zero-write behavior, symlink non-traversal, disabled apply, and presentation.
- Canonical `ccvalidate` shell workflow for fast, full, and release validation,
  plus explicitly authorized fast-forward completion of a feature branch.
- Disposable Git and bare-remote fixtures covering validation aggregation,
  finish success, refusal boundaries, push verification, and safe branch cleanup.
- Post-merge `ccvalidate publish` continuation with release validation, remote
  stability checks, exact main-only publication, live-remote verification,
  Git-private retained-feature evidence, conservative cleanup, and idempotency.
- Shared finish/publish publication helpers and disposable bare-remote coverage
  for topology, validation, remote-change, push, verification, and cleanup
  failure boundaries.

- Shared managed-PATH policy and disposable-home regression coverage for legacy
  normalization, repeated sourcing, shell ordering, and startup-file safety.
- Focused terminal-presentation fixtures for semantic colors, TTY detection,
  `NO_COLOR`, `TERM=dumb`, redirection, summaries, and long status labels.
- Shared PASS/WARN/FAIL/SKIP result aggregation for maintenance and reports.
- Read-only generated-document freshness and consolidated RC release gates.
- Focused RC integrity fixtures for stage aggregation, report privacy,
  redaction, incomplete sections, version state, and documentation freshness.
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

- Maintenance and repository commands now preserve batch child failures,
  continue safe independent work, distinguish invalid Git state, identify
  cached remote comparisons, and enforce clean-main fast-forward toolkit apply.
- Doctor full diagnostics now aggregate storage/SMART child WARN and FAIL
  results, developer update modes reject conflicts, and strict/detail command
  audits return nonzero for required defects.
- Generated command references now isolate caller-specific shell/program
  settings, bypass runtime dependency gates for help, and fail generation
  instead of misreporting incomplete help as stale committed documentation.
- Local full/release validation now executes each authoritative release gate
  once instead of repeating release-owned verification and documentation work.
- Monthly-health reports and operational update/kernel logs now resolve through
  the existing host-scoped report/log environment roots; private report and log
  modes remain 0600 inside mode-0700 directories.
- Monthly health now reports concise persistent-resource status without cleanup.
- Installer backup and repository bundle defaults now resolve through central
  environment helpers while preserving their existing global locations.
- Drive reports and qualification captures now use private 0700/0600 creation,
  and read-only qualification status no longer creates an empty report directory.

- `cc env path --fix` now atomically installs one canonical idempotent PATH
  block, removes only recognized legacy writers, preserves ambiguous user
  customization, and reports the parent-shell reload boundary accurately.
- Release integrity searches now use the declared core `grep` interface, so a
  missing optional `rg` executable cannot turn a forbidden-content check into a
  false PASS.
- Launcher safety fixtures now resolve `cc` only through their disposable home
  instead of inheriting a user-installed or system `cc` from the host PATH.
- Maintenance regressions now cover developer-manager authorization boundaries,
  supported-manager failure continuation, the full-update `DEV_UPDATES` gate,
  and Snap failure continuation into later Flatpak work through isolated mocks.
- PASS/WARN/FAIL/SKIP rendering, dotted status rows, summaries, progress rows,
  and diagnostic prefixes now use the shared presentation layer; ordinary
  data and generated or redirected output remain uncolored.
- `cc update` now continues safe diagnostics, reports every requested or skipped
  stage truthfully, and exits nonzero when any stage fails.
- Monthly-health reports are staged atomically at mode 0600, redact identity and
  credential-bearing content, expose incomplete sections, and aggregate an
  honest overall result.
- `VERSION` is the sole user-facing toolkit version/codename authority; legacy
  command and installer alpha labels are no longer presented as public versions.
- Root `ROADMAP.md`, `CHANGELOG.md`, command metadata, and generated-document
  ownership are explicit, with stale roadmap duplication removed.
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
