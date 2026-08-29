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
