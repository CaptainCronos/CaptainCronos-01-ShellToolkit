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
- `selftest-output.sh` validates normal/debug exit equivalence, sequential debug
  activity, invalid options, JSON integrity, and stdout/stderr separation. It is
  run separately because invoking it from `cc selftest` would recurse.
