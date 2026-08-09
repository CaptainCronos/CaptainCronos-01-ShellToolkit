# Toolkit Configuration

## Program Interfaces

Preferred command-line program choices are defined in `config/programs.conf`
and resolved by `lib/cc-programs.sh`. The file is intentionally limited to
executable names; command arguments, pipelines, privilege escalation, and shell
logic belong in libraries.

Inspect the configured capability interfaces with:

```bash
cc programs
cc programs check
cc programs show pkg-manager
```

Program reporting is read-only. Missing and incompatible programs are reported
separately and are never installed or replaced automatically.

System package behavior is implemented in `lib/cc-packages.sh`. On Debian-family
systems it resolves package operations, repository queries, and the installed
package database through `pkg-manager`, `pkg-query`, and `pkg-database`.
Configuration contains executable choices only; dry-run behavior, arguments,
and privilege escalation remain in the library.

Network-state inspection is implemented in `lib/cc-network.sh`. Linux interface,
address, and route operations resolve `network`; listener and connection
operations resolve `sockets`. NetworkManager control, DNS resolution, and
connectivity probes are separate concerns and are not mapped to these interfaces.

Service and system-log behavior is implemented in `lib/cc-services.sh`.
Systemd hosts resolve `service-manager` and `system-log`; every service operation
requires an explicit `system` or `user` scope. Queries remain unprivileged,
system mutations apply privilege escalation in the library, and user mutations
never add `sudo`.

HTTP behavior is implemented in `lib/cc-http.sh`. File acquisition resolves the
`download` capability (`wget` by default); API-style requests resolve `http-api`
(`curl` by default). The two interfaces are selected by operation semantics, not
treated as interchangeable clients. URLs, retry policy, output paths, and HTTP
arguments remain in the execution library or caller—not program configuration.

Structured-data behavior is implemented in `lib/cc-data.sh`. JSON operations
resolve `json` (`jq` by default). YAML operations resolve `yaml`, whose canonical
interface is the Kislyuk yq jq-wrapper. Because unrelated, incompatible programs
also use the name `yq`, program status requires both Kislyuk identity and the
serialization/query behavior Captain Cronos uses. JSON remains optional because
only optional JSON output modes consume it; YAML is required by asset and drive
workflows.

## User Configuration

Toolkit configuration lives in:

```text
~/.captaincronos/config
```

Use `cc config show`, `cc config get KEY`, and `cc config set KEY VALUE` to inspect or update settings.

## Update Settings

Developer ecosystem updates are disabled in the full maintenance workflow by default:

```bash
DEV_UPDATES="no"
```

This keeps `cc system-update` focused on OS and desktop/app package managers while still reporting npm, pipx, pip, cargo, go, and gem status. Set `DEV_UPDATES` only when you want supported developer package managers included in `cc update --apply`:

```bash
cc config set DEV_UPDATES yes
```

Even with config enabled, mutating developer updates still require an explicit `--apply` workflow. Use `cc update dev --dry-run` or `cc update npm --dry-run` for review first.
