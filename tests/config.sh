#!/usr/bin/env bash

# Literal expansion syntax is security-test data and must remain unexpanded.
# shellcheck disable=SC2016

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-config.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

TEST_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

export CAPTAIN_CRONOS_CONFIG_DIR="$TEST_DIR/config"
marker="$TEST_DIR/executed"

# Discovery and lookup are read-only before initialization.
[ "$(cc_config_get ABSENT_KEY fallback)" = fallback ] || fail 'missing key fallback changed'
[ ! -e "$CAPTAIN_CRONOS_CONFIG_DIR" ] || fail 'configuration discovery wrote state'

cc_config_init
[ "$(cc_config_get REPO_ROOT)" = "$HOME/GitHub" ] || fail 'safe HOME expansion changed'

payload="\$(touch $marker)"
cc_config_set INJECTION_TEST "$payload"
[ "$(cc_config_get INJECTION_TEST)" = "$payload" ] || fail 'literal command substitution was not preserved'
[ ! -e "$marker" ] || fail 'configuration value executed as shell code'

quoted='spaces "quotes" \\ backslash $PATH ${USER}'
cc_config_set QUOTING_TEST "$quoted"
[ "$(cc_config_get QUOTING_TEST)" = "$quoted" ] || fail 'configuration value did not round-trip safely'
cc_config_set HOMELESS_TEST '$HOMELESS/path'
[ "$(cc_config_get HOMELESS_TEST)" = '$HOMELESS/path' ] || fail 'HOME expansion changed a longer variable name'
if cc_config_set MULTILINE_TEST $'first\nsecond'; then
    fail 'multiline value that would corrupt the line format was accepted'
fi

if cc_config_set 'INVALID.KEY' value; then
    fail 'invalid configuration key was accepted'
fi
if cc_config_get 'INVALID.*' fallback >/dev/null; then
    fail 'invalid configuration lookup key was accepted'
fi

# Canonical defaults, global overrides, and current-host overrides resolve in
# documented order without evaluating stored shell syntax.
export CC_HOST_ID=config-fixture
host_config="$CAPTAIN_CRONOS_CONFIG_DIR/hosts/$CC_HOST_ID/config"
mkdir -p "$(dirname "$host_config")"
chmod 700 "$CAPTAIN_CRONOS_CONFIG_DIR" "$CAPTAIN_CRONOS_CONFIG_DIR/hosts" "$(dirname "$host_config")"
cc_config_set EDITOR global-editor
printf 'GLOBAL_ONLY="global"\n' >>"$(cc_config_file)"
printf 'HOST_ID="config-fixture"\nHOST_ROLE="developer"\nHOST_PROFILE="developer"\nEDITOR="host-editor"\n' >"$host_config"
chmod 600 "$host_config"
[ "$(cc_config_get AUTO_PUSH)" = no ] || fail 'canonical deployed default was not resolved'
[ "$(cc_config_get GLOBAL_ONLY)" = global ] || fail 'global override was not resolved'
[ "$(cc_config_get EDITOR)" = host-editor ] || fail 'host override did not win precedence'

# Validation distinguishes current, legacy, future, malformed, unknown, and
# insecure configuration without discarding operator-owned data.
validation="$(cc_config_validate)" || fail 'current configuration failed validation'
printf '%s\n' "$validation" | grep -q 'Configuration schema.*PASS.*v1' || fail 'current schema was not reported'
printf '%s\n' "$validation" | grep -q 'Host profile.*PASS.*developer' || fail 'valid profile was not reported'
printf '%s\n' "$validation" | grep -q 'Host selection.*WARN.*CC_HOST_ID override' || fail 'runtime host override was silent'
printf 'UNKNOWN_FORWARD_KEY="kept"\n' >>"$host_config"
validation="$(cc_config_validate)" || fail 'unknown harmless key became fatal'
printf '%s\n' "$validation" | grep -q 'Host config.*WARN' || fail 'unknown key did not warn'
printf '%s\n' "$validation" | grep -q 'unknown keys: UNKNOWN_FORWARD_KEY' || fail 'unknown key diagnostic omitted its name'
grep -q '^UNKNOWN_FORWARD_KEY=' "$host_config" || fail 'unknown key was discarded'

chmod 755 "$CAPTAIN_CRONOS_CONFIG_DIR"
validation="$(cc_config_validate)" || fail 'insecure root mode became fatal instead of repairable'
printf '%s\n' "$validation" | grep -q 'Configuration root.*WARN.*expected 700' || fail 'configuration root mode was not diagnosed'
chmod 700 "$CAPTAIN_CRONOS_CONFIG_DIR"
chmod 755 "$(dirname "$host_config")"
validation="$(cc_config_validate)" || fail 'insecure host-root mode became fatal instead of repairable'
printf '%s\n' "$validation" | grep -q 'Current host root.*WARN.*expected 700' || fail 'host root mode was not diagnosed'
chmod 700 "$(dirname "$host_config")"

invalid_dir="$TEST_DIR/invalid"
mkdir -p "$invalid_dir/hosts/config-fixture"
printf 'CONFIG_VERSION="99"\n' >"$invalid_dir/config"
printf 'HOST_ROLE="developer"\nHOST_PROFILE="missing-profile"\n' >"$invalid_dir/hosts/config-fixture/config"
chmod 600 "$invalid_dir/config" "$invalid_dir/hosts/config-fixture/config"
if CAPTAIN_CRONOS_CONFIG_DIR="$invalid_dir" CC_HOST_ID=config-fixture cc_config_validate >/dev/null; then
    fail 'future schema and invalid profile were accepted'
fi
printf 'CONFIG_VERSION="not-a-number"\nBROKEN LINE\n' >"$invalid_dir/config"
if CAPTAIN_CRONOS_CONFIG_DIR="$invalid_dir" CC_HOST_ID=config-fixture cc_config_validate >/dev/null; then
    fail 'malformed required configuration was accepted'
fi

# Migration is explicit, preview-only by default, backup-first, idempotent, and
# preserves unknown legacy keys byte-for-byte after the inserted schema marker.
migrate_dir="$TEST_DIR/migrate"
mkdir -p "$migrate_dir"
printf 'REPO_ROOT="$HOME/Legacy"\nCUSTOM_LEGACY="preserve"\n' >"$migrate_dir/config"
chmod 600 "$migrate_dir/config"
migrate_before="$(cat "$migrate_dir/config")"
migrate_before_hash="$(sha256sum "$migrate_dir/config" | cut -d' ' -f1)"
CAPTAIN_CRONOS_CONFIG_DIR="$migrate_dir" cc_config_migrate 0 >/dev/null
[ "$(cat "$migrate_dir/config")" = "$migrate_before" ] || fail 'migration preview changed config'
CAPTAIN_CRONOS_CONFIG_DIR="$migrate_dir" cc_config_migrate 1 >/dev/null
grep -q '^CONFIG_VERSION="1"$' "$migrate_dir/config" || fail 'migration did not add schema marker'
grep -q '^CUSTOM_LEGACY="preserve"$' "$migrate_dir/config" || fail 'migration discarded unknown key'
[ "$(find "$migrate_dir/backups/config" -type f | wc -l)" -eq 1 ] || fail 'migration backup missing'
[ "$(sha256sum "$(find "$migrate_dir/backups/config" -type f -print -quit)" | cut -d' ' -f1)" = "$migrate_before_hash" ] \
    || fail 'migration backup did not preserve the original bytes'
[ "$(stat -c %a "$migrate_dir/config")" = 600 ] || fail 'migration config mode was not private'
[ "$(stat -c %a "$(find "$migrate_dir/backups/config" -type f -print -quit)")" = 600 ] || fail 'migration backup mode was not private'
CAPTAIN_CRONOS_CONFIG_DIR="$migrate_dir" cc_config_migrate 1 >/dev/null
[ "$(find "$migrate_dir/backups/config" -type f | wc -l)" -eq 1 ] || fail 'idempotent migration created another backup'

old_schema_dir="$TEST_DIR/old-schema"
mkdir -p "$old_schema_dir"
printf 'CONFIG_VERSION="0"\nEDITOR="old-schema-operator"\n' >"$old_schema_dir/config"
chmod 600 "$old_schema_dir/config"
CAPTAIN_CRONOS_CONFIG_DIR="$old_schema_dir" cc_config_migrate 1 >/dev/null
grep -q '^CONFIG_VERSION="1"$' "$old_schema_dir/config" || fail 'old schema was not advanced'
grep -q '^EDITOR="old-schema-operator"$' "$old_schema_dir/config" || fail 'old schema value was reinterpreted'

unsupported_dir="$TEST_DIR/unsupported-schema"
mkdir -p "$unsupported_dir"
printf 'CONFIG_VERSION="99"\nEDITOR="future"\n' >"$unsupported_dir/config"
chmod 600 "$unsupported_dir/config"
unsupported_before="$(sha256sum "$unsupported_dir/config")"
if CAPTAIN_CRONOS_CONFIG_DIR="$unsupported_dir" cc_config_migrate 1 >/dev/null 2>&1; then
    fail 'future schema migration was accepted'
fi
[ "$(sha256sum "$unsupported_dir/config")" = "$unsupported_before" ] || fail 'future schema refusal changed config'
[ ! -e "$unsupported_dir/backups" ] || fail 'future schema refusal created backup state'
printf 'CONFIG_VERSION="1"\nBROKEN LINE\n' >"$unsupported_dir/config"
unsupported_before="$(sha256sum "$unsupported_dir/config")"
if CAPTAIN_CRONOS_CONFIG_DIR="$unsupported_dir" cc_config_migrate 1 >/dev/null 2>&1; then
    fail 'malformed schema migration was accepted'
fi
[ "$(sha256sum "$unsupported_dir/config")" = "$unsupported_before" ] || fail 'malformed schema refusal changed config'
[ ! -e "$unsupported_dir/backups" ] || fail 'malformed schema refusal created backup state'

# Unsafe targets and failed atomic replacement leave the original untouched.
symlink_dir="$TEST_DIR/symlink"
external="$TEST_DIR/external-config"
mkdir -p "$symlink_dir"
printf 'CONFIG_VERSION="1"\n' >"$external"
ln -s "$external" "$symlink_dir/config"
if CAPTAIN_CRONOS_CONFIG_DIR="$symlink_dir" cc_config_set EDITOR unsafe; then
    fail 'symlink config target was accepted'
fi
if CAPTAIN_CRONOS_CONFIG_DIR="$symlink_dir" cc_config_migrate 1 >/dev/null 2>&1; then
    fail 'migration reported success for a symlink config target'
fi
grep -q '^CONFIG_VERSION="1"$' "$external" || fail 'symlink refusal changed external config'
if CAPTAIN_CRONOS_CONFIG_DIR="$TEST_DIR/safe/../escape" cc_config_init; then
    fail 'path traversal configuration root was accepted'
fi

wrong_owner_dir="$TEST_DIR/wrong-owner"
mkdir -p "$wrong_owner_dir"
printf 'EDITOR="operator"\n' >"$wrong_owner_dir/config"
chmod 600 "$wrong_owner_dir/config"
wrong_owner_before="$(sha256sum "$wrong_owner_dir/config")"
if CAPTAIN_CRONOS_CONFIG_DIR="$wrong_owner_dir" bash -c '
    set -o pipefail
    source "$1"
    stat() {
        case "${1:-} ${2:-}" in
            "-c %u") printf "999999\\n" ;;
            *) command /usr/bin/stat "$@" ;;
        esac
    }
    cc_config_migrate 1
' _ "$PROJECT_ROOT/lib/cc-config.sh" >/dev/null 2>&1; then
    fail 'wrong-owner migration was accepted'
fi
[ "$(sha256sum "$wrong_owner_dir/config")" = "$wrong_owner_before" ] || fail 'wrong-owner refusal changed config'
[ ! -e "$wrong_owner_dir/backups" ] || fail 'wrong-owner refusal created backup state'

atomic_dir="$TEST_DIR/atomic"
mock_bin="$TEST_DIR/mock-bin"
mkdir -p "$atomic_dir" "$mock_bin"
printf 'CONFIG_VERSION="1"\nEDITOR="before"\n' >"$atomic_dir/config"
chmod 600 "$atomic_dir/config"
printf '%s\n' '#!/usr/bin/env bash' 'exit 73' >"$mock_bin/mv"
chmod 755 "$mock_bin/mv"
if PATH="$mock_bin:$PATH" CAPTAIN_CRONOS_CONFIG_DIR="$atomic_dir" cc_config_set EDITOR after; then
    fail 'mocked atomic rename failure reported success'
fi
grep -q '^EDITOR="before"$' "$atomic_dir/config" || fail 'atomic failure changed prior config'

# Stable stored identity survives hostname changes and isolates multiple hosts.
identity_dir="$TEST_DIR/identity"
mkdir -p "$identity_dir/hosts/alpha" "$identity_dir/hosts/beta"
printf 'alpha\n' >"$identity_dir/host-id"
printf 'HOST_ROLE="server"\nHOST_PROFILE="server"\n' >"$identity_dir/hosts/alpha/config"
printf 'HOST_ROLE="nas"\nHOST_PROFILE="truenas-scale"\n' >"$identity_dir/hosts/beta/config"
chmod 600 "$identity_dir/host-id" "$identity_dir/hosts/alpha/config" "$identity_dir/hosts/beta/config"
[ "$(env CAPTAIN_CRONOS_CONFIG_DIR="$identity_dir" CC_HOST_ID='' bash -c 'source "$1"; cc_config_host_id' _ "$PROJECT_ROOT/lib/cc-config.sh")" = alpha ] || fail 'stored identity was not authoritative'
[ "$(env CAPTAIN_CRONOS_CONFIG_DIR="$identity_dir" CC_HOST_ID='' bash -c 'source "$1"; cc_config_get HOST_ROLE' _ "$PROJECT_ROOT/lib/cc-config.sh")" = server ] || fail 'current host selection crossed host directories'
[ "$(CAPTAIN_CRONOS_CONFIG_DIR="$identity_dir" CC_HOST_ID=beta cc_config_get HOST_ROLE)" = nas ] || fail 'explicit fixture host selection failed'
override_status="$(CAPTAIN_CRONOS_CONFIG_DIR="$identity_dir" CC_HOST_ID=beta cc_config_status)"
printf '%s\n' "$override_status" | grep -q 'Identity source:.*runtime override (CC_HOST_ID)' || fail 'status hid the runtime identity override'
printf '%s\n' "$override_status" | grep -q 'Host selection.*WARN.*selects beta instead of stored alpha' || fail 'inherited override could silently select another host'
printf 'HOST_ID="legacy-other"\n' >>"$identity_dir/config"
chmod 600 "$identity_dir/config"
legacy_validation="$(env CAPTAIN_CRONOS_CONFIG_DIR="$identity_dir" CC_HOST_ID='' bash -c 'source "$1"; cc_config_validate' _ "$PROJECT_ROOT/lib/cc-config.sh")" || fail 'legacy HOST_ID mismatch became fatal'
printf '%s\n' "$legacy_validation" | grep -q 'Legacy host reference.*WARN.*differs from stored alpha' || fail 'legacy HOST_ID mismatch was not diagnosed'

# An existing legacy global config gains a stable identity without being
# rewritten when init is requested.
existing_dir="$TEST_DIR/existing"
mkdir -p "$existing_dir"
printf 'EDITOR="operator"\n' >"$existing_dir/config"
chmod 600 "$existing_dir/config"
CAPTAIN_CRONOS_CONFIG_DIR="$existing_dir" CC_HOST_ID=existing-host cc_config_init 1
[ "$(cat "$existing_dir/config")" = 'EDITOR="operator"' ] || fail 'init rewrote existing global config'
[ "$(cat "$existing_dir/host-id")" = existing-host ] || fail 'init did not create stable identity beside existing config'

# Status/show redact likely secrets and remain ANSI-free when redirected.
printf 'API_TOKEN="do-not-print"\n' >>"$(cc_config_file)"
printf 'lowercase_password="also-do-not-print"\n' >>"$(cc_config_file)"
show_output="$(cc_config_show)"
printf '%s\n' "$show_output" | grep -q 'API_TOKEN="<redacted>"' || fail 'secret value was not redacted'
printf '%s\n' "$show_output" | grep -q 'lowercase_password="<redacted>"' || fail 'case-insensitive secret key was not redacted'
if printf '%s\n' "$show_output" | grep -q 'do-not-print'; then fail 'secret leaked from config show'; fi
if printf '%s\n' "$(cc_config_status)" | LC_ALL=C grep -q $'\033'; then fail 'redirected config status contained ANSI'; fi

# Repeated sourcing retains behavior and must not initialize state.
source "$PROJECT_ROOT/lib/cc-config.sh"
[ "$(cc_config_get EDITOR)" = host-editor ] || fail 'repeated sourcing changed resolution'

printf 'Configuration safety tests: PASS\n'
