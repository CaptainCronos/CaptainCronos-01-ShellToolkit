# Captain Cronos Plugin Developer Guide

## Scope

Plugin API 1 is an experimental local contract for the beta3 development line.
It makes discovery and capability declarations real without adding a runtime,
command loader, installer, remote repository, or marketplace.

## Concepts

- A **capability** is an ability available on the current host. It may come from
  core platform detection, a configured program interface, or one enabled and
  healthy plugin.
- A **plugin** is an optional extension described by a validated manifest. It
  may declare capabilities and has a bounded entrypoint, but API 1 does not
  invoke it.
- A **dependency** is an external executable or registered Program Management
  interface required or optionally used by a plugin.
- A **command** is a user-facing interface in the toolkit registry. API 1
  plugins cannot register commands.
- A **profile** is host/user policy. It selects current-host context; plugin
  enablement is not inferred from profile names.

## Owned Roots and Precedence

Discovery inspects exactly two roots in deterministic order:

```text
<toolkit-root>/plugins/<plugin-id>/
<CC_HOST_HOME>/plugins/<plugin-id>/
```

The first root is repository-shipped and updates with the toolkit. The second is
operator-owned, host-scoped state and is preserved by install/update. PATH and
arbitrary directories are never searched. A duplicate ID is a conflict, not an
override: both records fail validation. Core capability names win, and two
active plugin providers for one capability both fail closed.

## Manifest

Each plugin directory contains `plugin.conf`. It is strict `key=value` data,
not shell syntax, and is never sourced. Blank lines and lines beginning with
`#` are ignored. Unknown or duplicate fields are invalid.

Required fields:

```text
plugin_api=1
id=example
name=Example Plugin
version=1.0.0
description=Example local capability provider
entrypoint=run
provides=example-capability
platforms=any
enabled=no
```

Optional fields:

```text
dependencies=git,yaml
optional_dependencies=jq
```

IDs, versions, capabilities, dependencies, and platform entries use lowercase
safe tokens containing letters, digits, dots, underscores, or hyphens. Lists
are comma-separated without shell expressions. `platforms` accepts `any` or
exact identifiers returned by `cc platform`. `enabled` is exactly `yes` or
`no`; external plugins are never enabled merely by appearing on disk.

API 1 does not accept command registrations or additional extension fields.
`plugin_api` is independent of the toolkit semantic version. A future API value
is inventoried as invalid rather than guessed or partially loaded.

## Trust and Safety

Discovery validates the known root and each candidate conservatively:

- roots, plugin directories, manifests, and entrypoint paths cannot be symlinks
  or traverse symlinked ancestors;
- the plugin directory name must equal the manifest ID;
- manifest and entrypoint must be regular files owned by the invoking user;
- world-writable code or metadata is invalid; group-writable material is WARN;
- entrypoints must stay lexically and physically inside the plugin directory;
- entrypoints must be executable, although discovery never executes them;
- unknown files and manifestless directories are reported, never executed or
  recursively interpreted.

Captain Cronos does not chmod operator code. Wrong ownership or unsafe modes
must be corrected explicitly by the operator. Cryptographic signing is not part
of this phase.

## State and Dependency Semantics

`cc plugin` uses the shared result vocabulary:

- `PASS`: explicitly enabled, supported, valid, and dependencies healthy.
- `WARN`: usable with a missing optional dependency or group-writable material;
  unknown material is also conservative WARN inventory.
- `FAIL`: invalid metadata/path/permissions, collision, or missing required
  dependency.
- `SKIP`: explicitly disabled or unsupported on the current platform.

Dependency checks reuse `lib/cc-deps.sh`, including semantic Program Management
capabilities. Discovery never installs a dependency.

`cc capability check NAME` distinguishes `available`, `unavailable`,
`unsupported`, `disabled`, and `missing-dependency`. The structured resolver in
`lib/cc-capabilities.sh` is authoritative; consumers must not parse the human
plugin table.

## Discovery Versus Execution

The following operations are read-only and never source or run plugin code:

```text
cc plugin
cc plugin list
cc plugin status
cc plugin info ID
cc capability
cc capability check NAME
cc plugin switches
cc capability switches
```

API 1 has no plugin execution or command-registration interface. An entrypoint
is validated now so a later runtime contract can start from a bounded identity.
Core command dispatch remains unchanged and a broken plugin cannot remove or
shadow core commands.

## Deferred Work

The following are intentional deferments, not implicit capabilities:

- plugin invocation and argument/exit propagation
- command registration and collision-aware dispatcher integration
- enable/disable or install/remove mutation commands
- profile-driven plugin policy
- privilege policy
- remote download, repositories, signing, marketplace, and auto-update

Any later execution slice must use the exact validated entrypoint without
`eval`, PATH lookup, `bash -c`, implicit sudo, or discovery-time execution.
