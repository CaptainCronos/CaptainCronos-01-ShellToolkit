# Host Awareness

`cc host` composes existing Blackbeard platform, configuration, capability, and
package abstractions into a read-only host view. It does not replace `cc
platform`, `cc capability`, `cc deps`, `cc env`, or `cc config`.

Observed facts include hostname, OS/platform, kernel, architecture, init and
package-manager selection, and conservative desktop/session evidence. Unknown
means evidence was not safely available. Facts are not persisted.

The toolkit host ID is a separate, stable local identifier owned by
`cc-config.sh`; it is not the hostname or `/etc/machine-id`. Roles remain one
explicit `HOST_ROLE` in private current-host configuration. Detection never
assigns a role.

`lib/cc-requirements.sh` declares conservative semantic role requirements and
resolves them through `cc-capabilities.sh`. Repository-owned
`config/requirements.conf` maps semantic capabilities to package names by
existing package-manager family; it is not per-host configuration and
`config/programs.conf` remains executable-selection data.

`cc host requirements` is observational: no writes, privilege escalation,
network fetch, package-index refresh, report, cache, or configuration changes.
`--apply` rebuilds the plan, installs only missing required provider-mapped
requirements through `cc-packages.sh`, then rechecks capabilities. Optional,
unknown, incompatible, and unsupported requirements never trigger installation.

Host reports intentionally do not persist or expose machine IDs, storage
serials, IP addresses, Tor data, Bitcoin paths, credentials, or topology.
