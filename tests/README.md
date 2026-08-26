# Tests

`tests/kernel.sh` uses temporary boot artifacts and mocked package/privilege
commands to verify kernel discovery, version ordering, protection, candidate
selection, ownership fail-safe behavior, status/list output, reboot state,
unsupported platforms, dry-run immutability, and the explicit apply path.

`tests/kernel-artifacts.sh` validates root-backed and dedicated `/boot`
filesystems, mounted and absent EFI paths, non-crossing usage, symlink safety,
kernel/initramfs/package correlation, every artifact state, shared kernel
classification, health severity, and command output using temporary fixtures.

`tests/kernel-platform.sh` validates Debian, RPM, Arch, openSUSE, unknown Linux,
and FreeBSD models; initramfs-tools, dracut, mkinitcpio, absent, additional, and
ambiguous provider states; EFI filesystem/runtime separation; bootloader
environments; support-matrix isolation; and platform/dependency output.

`tests/kernel-health-integration.sh` validates semantic snapshot consumption by
doctor and monthly-health, PASS/WARN/FAIL aggregation, reboot and newer-kernel
advisories, cleanup-as-maintenance behavior, reduced platforms, inspection
failure handling, stable monthly fields, and the absence of kernel CLI parsing
or mutation paths in either consumer.

Focused shell tests supplement `cc selftest`:

- `path-environment.sh` validates canonical managed PATH repair, known legacy
  normalization, five-source and fresh-shell idempotency, NVM/custom ordering,
  guarded profile interaction, ambiguous-line preservation, atomic no-op
  repair, inspection immutability, permissions, failures, and symlink safety
  using disposable home directories.
- `temp-lifecycle.sh` validates secure file/directory creation, deterministic and
  process-exit cleanup, failure status preservation, catchable INT/TERM cleanup,
  prior-trap chaining, nested registration, atomic commit/unregister behavior,
  path and symlink confinement, custom `TMPDIR`, and direct validation-command
  cleanup. Its SIGKILL fixture explicitly confirms that uncatchable termination
  can leave residue only inside the disposable test root.
- `retention.sh` validates empty/missing persistent trees, reports, logs,
  recovery backups, authoritative assets, curated history, bundles, reserved
  cache, unknown ownership, safe accounting, oldest/newest dates, symlink
  non-traversal, inspection and cleanup-preview zero-write fingerprints,
  disabled apply, contextual help, deterministic TSV, and ANSI-free output.
- `ccvalidate.sh` validates bare/fast/full/release orchestration, failure
  aggregation and continuation, help and ANSI-free output, repeated sourcing,
  and the explicit finish workflow with disposable repositories and bare
  remotes. It covers clean fast-forward success, post-push verification and
  branch cleanup, plus main/dirty/staged/untracked/origin/repository/divergence/
  conflict/validation/push/verification refusal boundaries. It never runs
  finish against the real repository or remote.
- `safety-contracts.sh` validates default-safe and explicit-apply behavior for
  launcher/full installation, toolkit update, system update, the complete update
  orchestrator, and monthly-health previews. Mutation paths run only through
  disposable homes and mocked Git/package/Snap/Flatpak/privilege interfaces;
  launcher resolution is isolated from host commands, Snap failure is shown not
  to skip later Flatpak work, legacy virtualenvs remain report-only, and routine
  GRUB and remote browser archive mutation are asserted unreachable.
- `dev-updates.sh` validates developer-manager detection and reporting, explicit
  npm/pipx apply boundaries, report-only ecosystems, failure continuation,
  absence of privilege escalation, and the `DEV_UPDATES` orchestrator gate using
  only disposable homes and mocked manager commands.
- `rc-integrity.sh` verifies release forbidden-content searches without
  requiring optional ripgrep and rejects false PASS results when forbidden
  maturity, documentation, or predictable temporary-path content is present.
  It also proves generated command references ignore caller shell hooks and
  program mappings instead of misreporting partial help output as stale.
- `dependencies.sh` validates semantic capability resolution, literal executable
  hints, and the `system-update` package-manager dependency regression.
- `package-management.sh` validates semantic package operations.
- `network.sh` validates configured network interfaces, semantic inspection,
  and non-Linux program selection.
- `services.sh` validates scoped service state, dry-run mutations, logs, and
  non-systemd program selection.
- `http.sh` validates semantic downloads, API requests, redirects, HTTP errors,
  dry runs, secret redaction, and configured client selection.
- `data.sh` validates JSON/YAML compatibility, parsing, validation, querying,
  safe expressions, YAML mutation, and required/optional capability behavior.
- `config.sh` validates safe configuration expansion, literal data handling,
  quoting, and configuration-key validation.
- `storage.sh` validates stable `lsblk` field parsing, unmounted drives, and
  CSV escaping for device metadata.
- `smart.sh` validates ATA/NVMe temperature, hours, lifetime, and integrated
  SMART-summary parsing against representative vendor fixtures.
- `assets.sh` validates asset-type containment, safe names, and structured-data
  round trips through the public asset command.
- `diagnostics.sh` validates shared debug state, stderr isolation, semantic and
  literal dependency traces, captured failures, and secret redaction.
- `progress.sh` validates reusable count-based TTY, non-TTY, debug, machine,
  failure, and cleanup progress behavior.
- `help.sh` validates registry-derived command inventory completeness, unique and
  correctly associated descriptions, aligned dotted leaders, long command names,
  unchanged help/dispatch statuses, and ANSI-free redirected color-policy modes.
- `selftest-output.sh` validates normal/debug exit equivalence, sequential debug
  activity, invalid options, JSON integrity, stdout/stderr separation, canonical
  result uniqueness, and registration/execution accounting. It is run separately
  because invoking it from `cc selftest` would recurse.
- `selftest-harness.sh` uses disposable child-command fixtures to validate
  canonical output ownership, line-safe live progress, normal/verbose capture,
  labeled failure streams, exit-status authority, and exact aggregate counting.
