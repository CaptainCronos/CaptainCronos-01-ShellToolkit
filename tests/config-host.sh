#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_DIR="$(mktemp -d)"
HOME_DIR="$TEST_DIR/home"

cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

run_init() {
    env HOME="$HOME_DIR" CC_HOME="$HOME_DIR/.captaincronos" \
        CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" \
        bash "$PROJECT_ROOT/tools/commands/init" "$@"
}

mkdir -p "$HOME_DIR"

# Dry-run discovery is zero-write.
run_init --host-id stable-host --role developer --profile developer >/dev/null
[ ! -e "$HOME_DIR/.captaincronos" ] || fail 'init dry-run created configuration state'

# First apply creates private global configuration, stable identity, and one
# private current-host tree.
run_init --apply --host-id stable-host --role developer --profile developer >/dev/null
global="$HOME_DIR/.captaincronos/config"
identity="$HOME_DIR/.captaincronos/host-id"
host="$HOME_DIR/.captaincronos/hosts/stable-host/config"
[ "$(stat -c %a "$HOME_DIR/.captaincronos")" = 700 ] || fail 'CC_HOME mode was not private'
[ "$(stat -c %a "$global")" = 600 ] || fail 'global config mode was not private'
[ "$(stat -c %a "$identity")" = 600 ] || fail 'identity mode was not private'
[ "$(stat -c %a "$host")" = 600 ] || fail 'host config mode was not private'
grep -q '^CONFIG_VERSION="1"$' "$global" || fail 'first init omitted schema marker'
[ "$(cat "$identity")" = stable-host ] || fail 'first init stored wrong identity'

# Second apply preserves all operator-owned host content and ignores new role or
# profile defaults once the host configuration exists.
printf 'CUSTOM_OPERATOR_KEY="preserve exactly"\n' >>"$host"
before="$(sha256sum "$host" | cut -d' ' -f1)"
run_init --apply --host-id stable-host --role server --profile server >/dev/null
after="$(sha256sum "$host" | cut -d' ' -f1)"
[ "$after" = "$before" ] || fail 'second init rewrote existing host config'

# Stored identity is authoritative across hostname changes, and an explicit
# --host-id runtime override cannot redirect mutation into another host.
mock_bin="$TEST_DIR/bin"
mkdir -p "$mock_bin"
printf '%s\n' '#!/usr/bin/env bash' 'printf renamed-machine\n' >"$mock_bin/hostname"
chmod 755 "$mock_bin/hostname"
env_output="$(env HOME="$HOME_DIR" CC_HOME="$HOME_DIR/.captaincronos" PATH="$mock_bin:$PATH" \
    CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" bash "$PROJECT_ROOT/tools/commands/env" host)" \
    || fail 'env rejected valid stored identity'
printf '%s\n' "$env_output" | grep -q 'Host ID:.*stable-host' || fail 'host rename changed stable identity'
if run_init --apply --host-id different-host --role server --profile server >/dev/null 2>&1; then
    fail 'init accepted cross-host identity replacement'
fi
[ ! -e "$HOME_DIR/.captaincronos/hosts/different-host/config" ] || fail 'cross-host refusal created config'

# A legitimate pre-beta2 hostname-fallback tree must transition in place. A
# different requested identity is refused before preview or apply can strand
# its existing configuration or persistent resources.
migration_home="$TEST_DIR/migration-home"
migration_bin="$TEST_DIR/migration-bin"
migration_root="$migration_home/.captaincronos"
migration_host="$migration_root/hosts/fallback-host"
mkdir -p "$migration_host/assets/operator-data" "$migration_host/reports/operator-data" \
    "$migration_host/plugins/operator-data" "$migration_bin"
# Literal HOME expansion syntax is configuration test data.
# shellcheck disable=SC2016
printf 'REPO_ROOT="$HOME/Legacy"\nEDITOR="operator"\n' >"$migration_root/config"
printf 'asset\n' >"$migration_host/assets/operator.asset"
printf 'report\n' >"$migration_host/reports/operator.report"
printf 'plugin\n' >"$migration_host/plugins/operator.plugin"
printf 'HOST_ID="fallback-host"\nHOST_ROLE="workstation"\nHOST_PROFILE="default"\nEDITOR="operator"\n' \
    >"$migration_host/config"
chmod 775 "$migration_root" "$migration_root/hosts" "$migration_host"
chmod 664 "$migration_root/config" "$migration_host/assets/operator.asset" \
    "$migration_host/reports/operator.report" "$migration_host/plugins/operator.plugin"
chmod 600 "$migration_host/config"
chmod 775 "$migration_host/assets/operator-data" "$migration_host/reports/operator-data" \
    "$migration_host/plugins/operator-data"
printf '%s\n' '#!/usr/bin/env bash' 'printf fallback-host\\n' >"$migration_bin/hostname"
chmod 755 "$migration_bin/hostname"
migration_env=(env HOME="$migration_home" CC_HOME="$migration_root" CC_HOST_ID= \
    PATH="$migration_bin:$PATH" CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT")

if "${migration_env[@]}" bash "$PROJECT_ROOT/tools/commands/init" --host-id different-host \
    --role workstation --profile default >/dev/null 2>&1; then
    fail 'init preview accepted an identity that would strand the fallback host tree'
fi
if "${migration_env[@]}" bash "$PROJECT_ROOT/tools/commands/init" --apply --host-id different-host \
    --role workstation --profile default >/dev/null 2>&1; then
    fail 'init apply accepted an identity that would strand the fallback host tree'
fi
if env HOME="$migration_home" CC_HOME="$migration_root" CC_HOST_ID=different-host \
    PATH="$migration_bin:$PATH" CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" \
    bash "$PROJECT_ROOT/tools/commands/init" --apply --role workstation --profile default \
    >/dev/null 2>&1; then
    fail 'init accepted an inherited override that would strand the fallback host tree'
fi
[ ! -e "$migration_root/host-id" ] || fail 'cross-host fallback refusal created identity'
[ ! -e "$migration_root/hosts/different-host" ] || fail 'cross-host fallback refusal created a new host root'

migration_before="$(find "$migration_host" -type f ! -name config -exec sha256sum {} + | sort)"
migration_host_config_before="$(sha256sum "$migration_host/config")"
"${migration_env[@]}" bash "$PROJECT_ROOT/tools/commands/config" migrate >/dev/null
[ ! -e "$migration_root/backups" ] || fail 'migration preview created a backup directory'
[ "$(stat -c %a "$migration_root")" = 775 ] || fail 'migration preview changed root permissions'
"${migration_env[@]}" bash "$PROJECT_ROOT/tools/commands/init" \
    --role workstation --profile default >/dev/null
[ ! -e "$migration_root/host-id" ] || fail 'init preview created identity'
[ "$(sha256sum "$migration_host/config")" = "$migration_host_config_before" ] \
    || fail 'init preview changed existing host config'

"${migration_env[@]}" bash "$PROJECT_ROOT/tools/commands/config" migrate --apply >/dev/null
"${migration_env[@]}" bash "$PROJECT_ROOT/tools/commands/init" --apply \
    --role workstation --profile default >/dev/null
[ "$(cat "$migration_root/host-id")" = fallback-host ] || fail 'fallback identity was not stored in place'
[ "$(stat -c %a "$migration_root")" = 700 ] || fail 'migration root mode was not normalized'
[ "$(stat -c %a "$migration_host")" = 700 ] || fail 'migration host-root mode was not normalized'
[ "$(stat -c %a "$migration_root/config")" = 600 ] || fail 'migration global config mode was not normalized'
grep -q '^CONFIG_VERSION="1"$' "$migration_root/config" || fail 'legacy schema was not migrated'
grep -q '^EDITOR="operator"$' "$migration_root/config" || fail 'global configuration value was not preserved'
[ "$(sha256sum "$migration_host/config")" = "$migration_host_config_before" ] \
    || fail 'existing fallback host config was not preserved'
[ "$(find "$migration_host" -type f ! -name config -exec sha256sum {} + | sort)" = "$migration_before" ] \
    || fail 'migration changed persistent host content'
[ "$(stat -c %a "$migration_host/assets/operator.asset")" = 664 ] \
    || fail 'migration recursively chmodded asset content'
[ "$(stat -c %a "$migration_host/reports/operator.report")" = 664 ] \
    || fail 'migration recursively chmodded report content'
[ "$(stat -c %a "$migration_host/plugins/operator.plugin")" = 664 ] \
    || fail 'migration recursively chmodded plugin content'
for persistent_dir in assets/operator-data reports/operator-data plugins/operator-data; do
    [ "$(stat -c %a "$migration_host/$persistent_dir")" = 775 ] \
        || fail "migration recursively chmodded persistent directory: $persistent_dir"
done

migration_snapshot="$(find "$migration_root" -type f -exec sha256sum {} + | sort)"
"${migration_env[@]}" bash "$PROJECT_ROOT/tools/commands/config" migrate --apply >/dev/null
"${migration_env[@]}" bash "$PROJECT_ROOT/tools/commands/init" --apply \
    --role workstation --profile default >/dev/null
[ "$(find "$migration_root" -type f -exec sha256sum {} + | sort)" = "$migration_snapshot" ] \
    || fail 'repeated migration changed the initialized configuration tree'
migration_validation="$("${migration_env[@]}" bash "$PROJECT_ROOT/tools/commands/config" validate)" \
    || fail 'migrated fallback fixture failed configuration validation'
printf '%s\n' "$migration_validation" | grep -q 'Overall.*PASS' \
    || fail 'migrated fallback fixture did not reach PASS'
migration_doctor="$("${migration_env[@]}" CC_DOCTOR_SKIP_KERNEL=1 \
    bash "$PROJECT_ROOT/tools/commands/doctor")" || fail 'migrated fallback Doctor fixture failed'
for diagnostic in 'Configuration root' 'Current host root' 'Global config' 'Host config' \
    'Host identity' 'Host selection' 'Configuration schema' 'Host role' 'Host profile'
do
    printf '%s\n' "$migration_doctor" | grep -q "$diagnostic.*PASS" \
        || fail "migrated fallback Doctor diagnostic did not pass: $diagnostic"
done

# A symlinked host collection is rejected before init can write through it.
symlink_home="$TEST_DIR/symlink-home"
external_hosts="$TEST_DIR/external-hosts"
mkdir -p "$symlink_home/.captaincronos" "$external_hosts"
printf 'CONFIG_VERSION="1"\n' >"$symlink_home/.captaincronos/config"
printf 'symlink-host\n' >"$symlink_home/.captaincronos/host-id"
chmod 700 "$symlink_home/.captaincronos"
chmod 600 "$symlink_home/.captaincronos/config" "$symlink_home/.captaincronos/host-id"
ln -s "$external_hosts" "$symlink_home/.captaincronos/hosts"
if env HOME="$symlink_home" CC_HOME="$symlink_home/.captaincronos" \
    CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" \
    bash "$PROJECT_ROOT/tools/commands/init" --apply --host-id symlink-host \
        --role server --profile server >/dev/null 2>&1; then
    fail 'init accepted a symlinked host root'
fi
[ ! -e "$external_hosts/symlink-host" ] || fail 'init wrote through symlinked host root'
mkdir -p "$external_hosts/symlink-host"
if env HOME="$symlink_home" CC_HOME="$symlink_home/.captaincronos" \
    CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" \
    bash "$PROJECT_ROOT/tools/commands/init" --apply --host-id symlink-host \
        --role server --profile server >/dev/null 2>&1; then
    fail 'init accepted an existing host directory through a symlinked ancestor'
fi
[ ! -e "$external_hosts/symlink-host/config" ] || fail 'init wrote through existing symlinked host ancestry'

# Invalid profile input and malformed authoritative configuration fail clearly.
if run_init --host-id stable-host --role server --profile missing >/dev/null 2>&1; then
    fail 'init accepted invalid profile'
fi
cp "$global" "$TEST_DIR/global.good"
printf 'CONFIG_VERSION="1"\nBROKEN LINE\n' >"$global"
if env HOME="$HOME_DIR" CC_HOME="$HOME_DIR/.captaincronos" \
    CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" bash "$PROJECT_ROOT/tools/commands/env" host >/dev/null 2>&1; then
    fail 'env fabricated context from malformed global config'
fi
mv "$TEST_DIR/global.good" "$global"

# Config command contracts retain status 2 for unknown switches/subcommands.
set +e
env HOME="$HOME_DIR" CC_HOME="$HOME_DIR/.captaincronos" \
    CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" bash "$PROJECT_ROOT/tools/commands/config" --bogus >/dev/null 2>&1
status=$?
set -e
[ "$status" -eq 2 ] || fail 'config unknown subcommand status was not 2'

# Doctor includes concise read-only configuration health without values.
mkdir -p "$HOME_DIR/bin"
cp "$PROJECT_ROOT/tools/cc" "$HOME_DIR/bin/cc"
chmod 755 "$HOME_DIR/bin/cc"
doctor_output="$(env HOME="$HOME_DIR" CC_HOME="$HOME_DIR/.captaincronos" CC_DOCTOR_SKIP_KERNEL=1 \
    CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" bash "$PROJECT_ROOT/tools/commands/doctor")" \
    || fail 'focused doctor fixture failed'
printf '%s\n' "$doctor_output" | grep -q 'Configuration schema.*PASS' || fail 'doctor omitted schema health'
printf '%s\n' "$doctor_output" | grep -q 'Host profile.*PASS' || fail 'doctor omitted profile health'
if printf '%s\n' "$doctor_output" | grep -q 'preserve exactly'; then fail 'doctor dumped config values'; fi

printf 'Configuration host-profile tests: PASS\n'
