# Tests

Focused shell tests supplement `cc selftest`:

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
