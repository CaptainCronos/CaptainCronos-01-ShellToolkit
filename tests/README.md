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
