# Container and Local-Service Foundation

Component 5 provides local-only `cc container` and `cc service` namespaces.
Docker and Podman are the only container providers, and client discovery is
separate from local runtime accessibility. Missing or inaccessible providers are
neutral states and never trigger installation, sudo, or host-health findings.

Container records are normalized safe operational metadata; inspect JSON,
environment, labels, and credentials are excluded. Inventories are bounded to
50 records by default (200 maximum). Logs are bounded to 100 lines by default
(1000 maximum), are not persisted, and are raw application output that may
contain secrets.

Lifecycle actions are limited to start, stop, and restart and require
`--apply`; omission is a dry run. Neither container actions nor public service
actions invoke sudo automatically. System-scope service actions therefore need
an invoking process that already has sufficient privilege. Compose, remote
administration, destructive operations, and container health policy are out of
scope.
