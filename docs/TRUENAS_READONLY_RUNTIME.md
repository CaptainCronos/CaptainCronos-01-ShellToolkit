# TrueNAS Read-Only Runtime

## Status and Scope

The `truenas-readonly` repository plugin is a fixture-validated consumer of the
plugin API 1 runtime. It is intentionally limited to local, read-only TrueNAS
SCALE inventory. It is not production-verified because development occurred on
Ubuntu without TrueNAS SCALE or `midclt` installed.

The plugin ID is `truenas-readonly`, its platform is `truenas-scale`, and it
provides `truenas.inventory.read`. It requires `midclt`, the configured `json`
interface (`jq` by default), and `timeout`. It never installs dependencies or
requests privilege elevation.

## Interface Contract

The TrueNAS API client repository documents `midclt call system.info` as a
local middleware client invocation. The current official TrueNAS API documents
the five query methods used here and their response fields:

- [`system.info`](https://api.truenas.com/v27.0/api_methods_system.info.html)
- [`pool.query`](https://api.truenas.com/v27.0/api_methods_pool.query.html)
- [`pool.dataset.query`](https://api.truenas.com/v27.0/api_methods_pool.dataset.query.html)
- [`disk.query`](https://api.truenas.com/v27.0/api_methods_disk.query.html)
- [`interface.query`](https://api.truenas.com/v27.0/api_methods_interface.query.html)
- [`midclt` client source and examples](https://github.com/truenas/api_client)

Those sources are authoritative for the current API documentation.
Compatibility of the exact schemas, local permissions, executable locations,
and timeout behavior on the operator's installed TrueNAS release awaits
real-host verification.

## Fixed Operations

| Plugin operation | Middleware method | Normalized output |
| --- | --- | --- |
| `system` | `system.info` | version, hostname, uptime, memory, CPU model, cores |
| `pools` | `pool.query` | name, status, health, size, allocated, free |
| `datasets` | `pool.dataset.query` | recursive name, type, pool, encryption, lock, used, available |
| `disks` | `disk.query` | name, model, serial, size, type, bus, pool |
| `network` | `interface.query` | name, type, description, MTU, link state, addresses |

There is no raw middleware-method interface. Unknown operations return usage
status 2 before `midclt` is called. Each call uses fixed executable paths,
passes only `call` and the statically selected method, and is bounded to 15
seconds. A middleware failure or timeout affects only that operation and its
status is returned. Malformed or structurally unexpected JSON fails with status
65. No aggregate operation hides partial failures.

## Platform Evidence

TrueNAS SCALE detection requires all of the following read-only evidence:

- Debian identity from `/etc/os-release`;
- a kernel release containing `production+truenas`;
- a numeric TrueNAS release in `/etc/version`;
- a non-symlink executable at `/usr/bin/midclt`.

The evidence is conjunctive and does not use hostname. Fixtures prove ordinary
Ubuntu and Debian do not match merely because one piece of evidence is present.
Detection and capability checks never call `midclt`.

## Real-Host Read-Only Verification

Run the following later on the actual TrueNAS SCALE host from a temporary shell
session. The commands make no changes, create no persistent configuration, and
do not request or print credentials. Review output locally before sharing it;
hostnames, IP addresses, disk serials, and dataset names may be sensitive.

```bash
printf 'OS ID: '
awk -F= '$1=="ID" {gsub(/^"|"$/, "", $2); print $2}' /etc/os-release
printf 'TrueNAS version: '
sed -n '1p' /etc/version
printf 'Kernel: '
uname -r
command -v midclt
ls -ld /usr/bin/midclt /usr/bin/jq /usr/bin/timeout

for method in system.info pool.query pool.dataset.query disk.query interface.query; do
    printf '\n===== %s =====\n' "$method"
    /usr/bin/timeout --signal=TERM --kill-after=2 15s \
        /usr/bin/midclt call "$method" | \
        /usr/bin/jq 'if type == "array" then {type: type, count: length, first_keys: (first // {} | keys)} else {type: type, keys: keys} end'
done
```

Then, from the checked-out toolkit, run each operation and confirm its reduced
schema without redirecting output to persistent host files:

```bash
cc capability check truenas.inventory.read
cc plugin run truenas-readonly system
cc plugin run truenas-readonly pools
cc plugin run truenas-readonly datasets
cc plugin run truenas-readonly disks
cc plugin run truenas-readonly network
```

Production compatibility must remain unverified until these checks confirm the
platform evidence, executable locations, middleware authorization, response
types/fields, and normalized output on the target release.
