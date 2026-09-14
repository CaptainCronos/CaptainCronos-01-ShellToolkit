# System and Service Health Monitoring

`cc health` is the canonical, local health-inspection namespace. `status` is
the default; `system`, `resources`, `services`, and `timers` expose focused
views. `diagnose` is the only health view that reads journal evidence, and it
uses a fixed 24-hour window with a finite record limit.

All ordinary health paths are read-only, unprivileged, local, and bounded.
They do not run `sudo`, mutate units, install packages, write reports, start
SMART tests, or perform external network probes. Linux/systemd is the complete
service adapter. Other init systems return explicit reduced/unsupported data;
portable resource evidence remains available where possible.

## Records

The service TSV schema is `scope, unit, description, load_state, active_state,
sub_state, enabled_state, unit_type, pid, restart_count, collection_state`.
The timer schema is `scope, unit, next_run, last_run, activates, active_state,
enabled_state, collection_state`. Resource records are `name, value, unit,
state, source, observed_at`. Findings use the shared Component 3-compatible
schema `state, code, layer, subject, message, evidence_source, observed_at`.

An inactive service is an observation, not an error. Static, generated,
oneshot, disabled, and installed-but-idle units are therefore not unhealthy by
default. A failed systemd unit is actionable observed evidence. Restricted,
unavailable user-bus, and unsupported collection states are represented rather
than promoted to failures.

## Policy

`config/health-policy.conf` is repository-owned TSV with
`selector_type|selector|scope|unit|expectation|severity`. Supported selectors
are `role` and `profile`; expectations are `present`, `active`, `enabled`, and
`absent`; severity is `WARN` or `FAIL`. The production catalog is intentionally
empty. Policy is the only mechanism that converts an inactive or disabled unit
into a health failure. Host package requirements do not imply service policy.

## Composition

`lib/cc-health.sh` composes the existing kernel snapshot, local network
findings, and lightweight storage findings. It does not invoke network
diagnosis, storage diagnosis, broad SMART inspection, or duplicate their raw
parsers. `cc doctor` remains a bounded consumer while retaining its repository,
installation, configuration, and requirement checks. `cc monthly-health`
remains a persistent report consumer; broader report migration is deliberately
deferred.

## Journal contract

`_cc_log_query scope since limit [unit] [priority]` is the sole semantic
journal query contract in `cc-services.sh`. Scope, non-empty time window, and
positive record limit are mandatory. Wrapper helpers preserve the same bound.
No caller may request an unlimited journal scan.
