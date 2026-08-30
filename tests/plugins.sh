#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_DIR="$(mktemp -d)"

cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

assert_contains() {
    local text="$1" expected="$2" label="$3"
    printf '%s\n' "$text" | grep -Fq -- "$expected" || fail "$label"
}

make_roots() {
    local toolkit="$1" host="$2"
    mkdir -p "$toolkit/plugins" "$host/plugins"
    chmod 700 "$toolkit/plugins" "$host/plugins"
}

make_plugin() {
    local root="$1" id="$2" provides="$3" enabled="${4:-yes}" platforms="${5:-any}"
    local dependencies="${6:-}" optional_dependencies="${7:-}" directory="$root/$id"
    mkdir -p "$directory"
    chmod 700 "$directory"
    {
        printf 'plugin_api=1\n'
        printf 'id=%s\n' "$id"
        printf 'name=%s fixture\n' "$id"
        printf 'version=1.0.0\n'
        printf 'description=Disposable plugin fixture\n'
        printf 'entrypoint=run\n'
        printf 'provides=%s\n' "$provides"
        [ -z "$dependencies" ] || printf 'dependencies=%s\n' "$dependencies"
        [ -z "$optional_dependencies" ] || printf 'optional_dependencies=%s\n' "$optional_dependencies"
        printf 'platforms=%s\n' "$platforms"
        printf 'enabled=%s\n' "$enabled"
    } > "$directory/plugin.conf"
    # Literal variables are evaluated only if discovery executes the fixture.
    # shellcheck disable=SC2016
    printf '%s\n' '#!/usr/bin/env bash' 'printf "executed\\n" >> "${CC_PLUGIN_EXEC_TRACE:?}"' 'exit 0' > "$directory/run"
    chmod 600 "$directory/plugin.conf"
    chmod 700 "$directory/run"
}

inventory() {
    TOOLKIT_ROOT="$1" CC_HOST_HOME="$2" cc_plugin_inventory_tsv
}

source "$PROJECT_ROOT/lib/cc-capabilities.sh"

# Empty roots and one/multiple valid plugins are deterministic and executable
# entrypoints are never reached by discovery.
empty_toolkit="$TEST_DIR/empty-toolkit" empty_host="$TEST_DIR/empty-host"
make_roots "$empty_toolkit" "$empty_host"
[ -z "$(inventory "$empty_toolkit" "$empty_host")" ] || fail 'empty roots produced plugin inventory'

toolkit="$TEST_DIR/toolkit" host="$TEST_DIR/host"
make_roots "$toolkit" "$host"
make_plugin "$toolkit/plugins" zulu zulu-cap
make_plugin "$toolkit/plugins" alpha alpha-cap
trace="$TEST_DIR/entrypoint.trace"
CC_PLUGIN_EXEC_TRACE="$trace" output="$(inventory "$toolkit" "$host")"
[ ! -e "$trace" ] || fail 'plugin discovery executed an entrypoint'
assert_contains "$output" $'alpha\talpha fixture\tPASS' 'valid plugin was not healthy'
assert_contains "$output" $'zulu\tzulu fixture\tPASS' 'multiple valid plugins were not discovered'
[ "$(printf '%s\n' "$output" | cut -f1 | paste -sd, -)" = alpha,zulu ] || fail 'plugin ordering was not deterministic'

# Disabled, unsupported, missing-required, and missing-optional dependency state.
make_plugin "$host/plugins" disabled disabled-cap no
make_plugin "$host/plugins" unsupported unsupported-cap yes not-a-platform
make_plugin "$host/plugins" required required-cap yes any definitely-missing-plugin-program
make_plugin "$host/plugins" optional optional-cap yes any '' definitely-missing-optional-program
make_plugin "$host/plugins" group-writable group-writable-cap
chmod 770 "$host/plugins/group-writable" "$host/plugins/group-writable/run"
chmod 660 "$host/plugins/group-writable/plugin.conf"
output="$(inventory "$toolkit" "$host")"
assert_contains "$output" $'disabled\tdisabled fixture\tSKIP' 'disabled plugin state was wrong'
assert_contains "$output" 'disabled by manifest' 'disabled plugin reason was absent'
assert_contains "$output" $'unsupported\tunsupported fixture\tSKIP' 'unsupported plugin state was wrong'
assert_contains "$output" 'missing required dependency' 'required dependency failure was absent'
assert_contains "$output" $'optional\toptional fixture\tWARN' 'optional dependency warning was absent'
assert_contains "$output" $'group-writable\tgroup-writable fixture\tWARN' 'group-writable plugin was not reported'
result="$(TOOLKIT_ROOT="$toolkit" CC_HOST_HOME="$host" cc_capability_result group-writable-cap)"
assert_contains "$result" $'unavailable\tFAIL' 'group-writable capability was reported available'

# Strict data-only schema rejects malformed, unknown, and future metadata.
make_plugin "$host/plugins" malformed malformed-cap
printf 'BROKEN LINE\n' >> "$host/plugins/malformed/plugin.conf"
make_plugin "$host/plugins" unknown-field unknown-field-cap
printf 'commands=shadow:run\n' >> "$host/plugins/unknown-field/plugin.conf"
make_plugin "$host/plugins" future future-cap
sed -i 's/plugin_api=1/plugin_api=2/' "$host/plugins/future/plugin.conf"
output="$(inventory "$toolkit" "$host")"
assert_contains "$output" 'malformed line' 'malformed manifest was accepted'
assert_contains "$output" 'unknown field commands' 'unknown manifest field was accepted'
assert_contains "$output" 'unsupported plugin_api 2' 'future plugin API was accepted'

# Duplicate IDs and duplicate capability providers fail closed, as does a
# collision with the core capability namespace.
duplicate_toolkit="$TEST_DIR/duplicate-toolkit" duplicate_host="$TEST_DIR/duplicate-host"
make_roots "$duplicate_toolkit" "$duplicate_host"
make_plugin "$duplicate_toolkit/plugins" same repo-cap
make_plugin "$duplicate_host/plugins" same host-cap
make_plugin "$duplicate_toolkit/plugins" provider-one shared-cap
make_plugin "$duplicate_host/plugins" provider-two shared-cap
make_plugin "$duplicate_host/plugins" core-provider git
output="$(inventory "$duplicate_toolkit" "$duplicate_host")"
[ "$(printf '%s\n' "$output" | grep -Fc 'duplicate plugin id')" -eq 2 ] || fail 'duplicate plugin ID did not invalidate both records'
[ "$(printf '%s\n' "$output" | grep -Fc 'duplicate capability provider: shared-cap')" -eq 2 ] || fail 'duplicate capability did not invalidate both providers'
assert_contains "$output" 'capability conflicts with core: git' 'core capability collision was accepted'

# Path traversal, symlinked directories/entrypoints, unsafe permissions,
# missing entrypoints, and non-executable entrypoints all fail closed.
safety_toolkit="$TEST_DIR/safety-toolkit" safety_host="$TEST_DIR/safety-host"
make_roots "$safety_toolkit" "$safety_host"
make_plugin "$safety_host/plugins" traversal traversal-cap
sed -i 's|entrypoint=run|entrypoint=../outside|' "$safety_host/plugins/traversal/plugin.conf"
make_plugin "$safety_host/plugins" linked-entry linked-entry-cap
mv "$safety_host/plugins/linked-entry/run" "$TEST_DIR/outside-entry"
ln -s "$TEST_DIR/outside-entry" "$safety_host/plugins/linked-entry/run"
mkdir -p "$TEST_DIR/symlink-target"
ln -s "$TEST_DIR/symlink-target" "$safety_host/plugins/linked-root"
root_link_host="$TEST_DIR/root-link-host"
mkdir -p "$root_link_host" "$TEST_DIR/external-plugin-root"
ln -s "$TEST_DIR/external-plugin-root" "$root_link_host/plugins"
make_plugin "$safety_host/plugins" unsafe-mode unsafe-mode-cap
chmod 666 "$safety_host/plugins/unsafe-mode/plugin.conf"
make_plugin "$safety_host/plugins" unsafe-directory unsafe-directory-cap
chmod 707 "$safety_host/plugins/unsafe-directory"
make_plugin "$safety_host/plugins" unsafe-entry-dir unsafe-entry-dir-cap
mkdir "$safety_host/plugins/unsafe-entry-dir/bin"
mv "$safety_host/plugins/unsafe-entry-dir/run" "$safety_host/plugins/unsafe-entry-dir/bin/run"
sed -i 's|entrypoint=run|entrypoint=bin/run|' "$safety_host/plugins/unsafe-entry-dir/plugin.conf"
chmod 707 "$safety_host/plugins/unsafe-entry-dir/bin"
make_plugin "$safety_host/plugins" missing-entry missing-entry-cap
rm "$safety_host/plugins/missing-entry/run"
make_plugin "$safety_host/plugins" nonexec nonexec-cap
chmod 600 "$safety_host/plugins/nonexec/run"
output="$(inventory "$safety_toolkit" "$safety_host")"
assert_contains "$output" 'unsafe entrypoint path' 'path traversal was accepted'
assert_contains "$output" 'symlink entrypoint path' 'symlink entrypoint was accepted'
assert_contains "$output" 'symlink plugin directory' 'symlink plugin directory was accepted'
root_output="$(inventory "$safety_toolkit" "$root_link_host")"
assert_contains "$root_output" 'unsafe plugin root' 'symlinked host plugin root was accepted'
assert_contains "$output" 'manifest must be an owner-controlled regular file' 'unsafe manifest permissions were accepted'
assert_contains "$output" 'unsafe plugin directory' 'unsafe plugin directory permissions were accepted'
assert_contains "$output" 'unsafe entrypoint directory' 'unsafe entrypoint parent permissions were accepted'
assert_contains "$output" 'entrypoint must be owner-controlled regular file' 'missing entrypoint was accepted'
assert_contains "$output" 'entrypoint is not executable' 'non-executable entrypoint was accepted'

# Unknown material is inventoried but not executed or recursively interpreted.
# Literal variable is evaluated only if discovery executes the fixture.
# shellcheck disable=SC2016
printf '%s\n' '#!/usr/bin/env bash' 'printf unknown >> "${CC_PLUGIN_EXEC_TRACE:?}"' > "$safety_host/plugins/unknown-executable"
chmod 700 "$safety_host/plugins/unknown-executable"
mkdir -p "$safety_host/plugins/no-manifest/nested"
printf 'ignored\n' > "$safety_host/plugins/no-manifest/nested/run"
export CC_PLUGIN_EXEC_TRACE="$trace"
output="$(inventory "$safety_toolkit" "$safety_host")"
[ ! -e "$trace" ] || fail 'unknown plugin material was executed'
assert_contains "$output" 'unknown material' 'unknown root material was not reported'
assert_contains "$output" 'no plugin.conf manifest' 'manifestless directory was not reported'

# Capability resolution is authoritative across plugin, disabled, dependency,
# platform/program core, and unknown providers.
resolution_toolkit="$TEST_DIR/resolution-toolkit" resolution_host="$TEST_DIR/resolution-host"
make_roots "$resolution_toolkit" "$resolution_host"
make_plugin "$resolution_host/plugins" available demo-available
make_plugin "$resolution_host/plugins" disabled-provider demo-disabled no
make_plugin "$resolution_host/plugins" dependency-provider demo-dependency yes any definitely-missing-plugin-program
make_plugin "$resolution_toolkit/plugins" disabled-shadow shared-resolution no
make_plugin "$resolution_host/plugins" active-shadow shared-resolution
result="$(TOOLKIT_ROOT="$resolution_toolkit" CC_HOST_HOME="$resolution_host" cc_capability_result demo-available)"
assert_contains "$result" $'available\tPASS\tplugin/available' 'valid plugin capability was unavailable'
result="$(TOOLKIT_ROOT="$resolution_toolkit" CC_HOST_HOME="$resolution_host" cc_capability_result demo-disabled)"
assert_contains "$result" $'disabled\tSKIP' 'disabled capability provider was not distinguished'
result="$(TOOLKIT_ROOT="$resolution_toolkit" CC_HOST_HOME="$resolution_host" cc_capability_result demo-dependency)"
assert_contains "$result" $'missing-dependency\tFAIL' 'dependency-backed capability state was wrong'
result="$(TOOLKIT_ROOT="$resolution_toolkit" CC_HOST_HOME="$resolution_host" cc_capability_result git)"
assert_contains "$result" $'available\tPASS\tcore/platform' 'core capability resolution regressed'
result="$(TOOLKIT_ROOT="$resolution_toolkit" CC_HOST_HOME="$resolution_host" cc_capability_result no-such-capability)"
assert_contains "$result" $'unavailable\tFAIL\tnone' 'unknown capability state was wrong'
result="$(TOOLKIT_ROOT="$resolution_toolkit" CC_HOST_HOME="$resolution_host" cc_capability_result shared-resolution)"
[ "$(printf '%s\n' "$result" | wc -l | tr -d ' ')" -eq 1 ] || fail 'capability resolver emitted multiple semantic results'
assert_contains "$result" $'available\tPASS\tplugin/active-shadow' 'active provider did not outrank disabled provider'

# Command declarations are not part of API 1, so neither core nor plugin
# commands can be shadowed in this slice. Broken manifests do not affect core.
command_toolkit="$TEST_DIR/command-toolkit" command_host="$TEST_DIR/command-host"
make_roots "$command_toolkit" "$command_host"
make_plugin "$command_host/plugins" shadow-core shadow-core-cap
printf 'commands=version:run\n' >> "$command_host/plugins/shadow-core/plugin.conf"
make_plugin "$command_host/plugins" shadow-plugin shadow-plugin-cap
printf 'commands=shared:run\n' >> "$command_host/plugins/shadow-plugin/plugin.conf"
make_plugin "$command_host/plugins" shadow-plugin-two shadow-plugin-two-cap
printf 'commands=shared:run\n' >> "$command_host/plugins/shadow-plugin-two/plugin.conf"
output="$(inventory "$command_toolkit" "$command_host")"
[ "$(printf '%s\n' "$output" | grep -Fc 'unknown field commands')" -eq 3 ] || fail 'command-bearing manifests were not rejected'
bash "$PROJECT_ROOT/tools/cc" version >/dev/null || fail 'broken plugins disabled a core command'

# Host roots are isolated and repeated library sourcing is idempotent.
host_a="$TEST_DIR/host-a" host_b="$TEST_DIR/host-b" isolated_toolkit="$TEST_DIR/isolated-toolkit"
make_roots "$isolated_toolkit" "$host_a"
mkdir -p "$host_b/plugins"; chmod 700 "$host_b/plugins"
make_plugin "$host_a/plugins" only-a only-a-cap
assert_contains "$(inventory "$isolated_toolkit" "$host_a")" 'only-a-cap' 'host A plugin was absent'
[ -z "$(inventory "$isolated_toolkit" "$host_b")" ] || fail 'host A plugin leaked into host B'
source "$PROJECT_ROOT/lib/cc-plugins.sh"
source "$PROJECT_ROOT/lib/cc-capabilities.sh"
assert_contains "$(inventory "$isolated_toolkit" "$host_a")" 'only-a-cap' 'repeated sourcing changed discovery'
source "$PROJECT_ROOT/lib/cc-platform.sh"
result="$(TOOLKIT_ROOT="$isolated_toolkit" CC_HOST_HOME="$host_a" cc_capability_result only-a-cap)"
assert_contains "$result" $'available\tPASS\tplugin/only-a' 'platform re-source replaced authoritative resolution'

# Runtime is explicit, resolves one exact absolute entrypoint, and performs a
# complete fresh inventory validation immediately before direct execution.
runtime_toolkit="$TEST_DIR/runtime-toolkit" runtime_host="$TEST_DIR/runtime-host"
make_roots "$runtime_toolkit" "$runtime_host"
make_plugin "$runtime_host/plugins" runtime-plugin runtime-cap
runtime_trace="$TEST_DIR/runtime.args"
runtime_stdout="$TEST_DIR/runtime.stdout" runtime_stderr="$TEST_DIR/runtime.stderr"
cat >"$runtime_host/plugins/runtime-plugin/run" <<'EOF_RUNTIME'
#!/usr/bin/env bash
printf 'runtime stdout\n'
printf 'runtime stderr\n' >&2
printf '<%s>\n' "$@" >"${CC_RUNTIME_ARG_TRACE:?}"
exit 23
EOF_RUNTIME
chmod 700 "$runtime_host/plugins/runtime-plugin/run"
mkdir "$TEST_DIR/runtime-path"
cat >"$TEST_DIR/runtime-path/run" <<'EOF_PATH_RUN'
#!/usr/bin/env bash
printf 'PATH substitute executed\n' >"${CC_RUNTIME_PATH_TRACE:?}"
EOF_PATH_RUN
chmod 700 "$TEST_DIR/runtime-path/run"
runtime_path_trace="$TEST_DIR/runtime-path.trace"
runtime_status=0
TOOLKIT_ROOT="$runtime_toolkit" CC_HOST_HOME="$runtime_host" \
    CC_RUNTIME_ARG_TRACE="$runtime_trace" CC_RUNTIME_PATH_TRACE="$runtime_path_trace" \
    PATH="$TEST_DIR/runtime-path:$PATH" \
    cc_plugin_run runtime-plugin operation 'argument with spaces' '*' '--literal=value' \
    >"$runtime_stdout" 2>"$runtime_stderr" || runtime_status=$?
[ "$runtime_status" -eq 23 ] || fail 'plugin exit status was not propagated'
assert_contains "$(cat "$runtime_stdout")" 'runtime stdout' 'plugin stdout was not preserved'
assert_contains "$(cat "$runtime_stderr")" 'runtime stderr' 'plugin stderr was not preserved'
[ "$(cat "$runtime_trace")" = $'<operation>\n<argument with spaces>\n<*>\n<--literal=value>' ] || fail 'plugin arguments were not preserved'
[ ! -e "$runtime_path_trace" ] || fail 'PATH substituted for the validated entrypoint'

runtime_status=0
env CC_HOST_HOME="$runtime_host" CC_RUNTIME_ARG_TRACE="$runtime_trace" \
    CC_RUNTIME_PATH_TRACE="$runtime_path_trace" PATH="$TEST_DIR/runtime-path:$PATH" \
    CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" \
    bash "$PROJECT_ROOT/tools/cc" plugin run runtime-plugin public-operation 'public argument' \
    >"$runtime_stdout" 2>"$runtime_stderr" || runtime_status=$?
[ "$runtime_status" -eq 23 ] || fail 'public plugin runtime did not propagate status'
[ "$(cat "$runtime_trace")" = $'<public-operation>\n<public argument>' ] || fail 'public plugin runtime changed arguments'
[ ! -e "$runtime_path_trace" ] || fail 'public runtime used a PATH entrypoint substitute'

make_plugin "$runtime_host/plugins" runtime-disabled disabled-runtime-cap no
if TOOLKIT_ROOT="$runtime_toolkit" CC_HOST_HOME="$runtime_host" cc_plugin_run runtime-disabled operation >/dev/null 2>&1; then
    fail 'disabled plugin executed'
fi
make_plugin "$runtime_host/plugins" runtime-unsupported unsupported-runtime-cap yes impossible-platform
if TOOLKIT_ROOT="$runtime_toolkit" CC_HOST_HOME="$runtime_host" cc_plugin_run runtime-unsupported operation >/dev/null 2>&1; then
    fail 'unsupported plugin executed'
fi
make_plugin "$runtime_host/plugins" runtime-missing missing-runtime-cap yes any definitely-missing-plugin-program
if TOOLKIT_ROOT="$runtime_toolkit" CC_HOST_HOME="$runtime_host" cc_plugin_run runtime-missing operation >/dev/null 2>&1; then
    fail 'plugin with a missing dependency executed'
fi
make_plugin "$runtime_host/plugins" runtime-optional optional-runtime-cap yes any '' definitely-missing-optional-program
CC_PLUGIN_EXEC_TRACE="$runtime_trace" TOOLKIT_ROOT="$runtime_toolkit" CC_HOST_HOME="$runtime_host" \
    cc_plugin_run runtime-optional operation >/dev/null || fail 'optional dependency warning blocked runtime'
make_plugin "$runtime_host/plugins" runtime-invalid invalid-runtime-cap
printf 'unknown_runtime_field=yes\n' >>"$runtime_host/plugins/runtime-invalid/plugin.conf"
if TOOLKIT_ROOT="$runtime_toolkit" CC_HOST_HOME="$runtime_host" cc_plugin_run runtime-invalid operation >/dev/null 2>&1; then
    fail 'invalid plugin executed'
fi

make_plugin "$runtime_host/plugins" changed-after-discovery changed-runtime-cap
inventory "$runtime_toolkit" "$runtime_host" >/dev/null
printf 'changed=yes\n' >>"$runtime_host/plugins/changed-after-discovery/plugin.conf"
if TOOLKIT_ROOT="$runtime_toolkit" CC_HOST_HOME="$runtime_host" cc_plugin_run changed-after-discovery operation >/dev/null 2>&1; then
    fail 'manifest changed after discovery executed without revalidation'
fi
make_plugin "$runtime_host/plugins" entry-changed entry-changed-cap
inventory "$runtime_toolkit" "$runtime_host" >/dev/null
chmod 702 "$runtime_host/plugins/entry-changed/run"
if TOOLKIT_ROOT="$runtime_toolkit" CC_HOST_HOME="$runtime_host" cc_plugin_run entry-changed operation >/dev/null 2>&1; then
    fail 'entrypoint changed after discovery executed without revalidation'
fi
make_plugin "$runtime_host/plugins" wrong-owner wrong-owner-cap
mkdir "$TEST_DIR/ownership-bin"
cat >"$TEST_DIR/ownership-bin/stat" <<EOF_OWNERSHIP_STAT
#!/usr/bin/env bash
if [ "\${1:-}" = -c ] && [ "\${2:-}" = %u ] && [ "\${4:-}" = "$runtime_host/plugins/wrong-owner/run" ]; then
    printf '999999\n'
    exit 0
fi
exec /usr/bin/stat "\$@"
EOF_OWNERSHIP_STAT
chmod 700 "$TEST_DIR/ownership-bin/stat"
if PATH="$TEST_DIR/ownership-bin:$PATH" TOOLKIT_ROOT="$runtime_toolkit" CC_HOST_HOME="$runtime_host" \
    cc_plugin_run wrong-owner operation >/dev/null 2>&1; then
    fail 'wrong-owner runtime entrypoint executed'
fi
make_plugin "$runtime_host/plugins" runtime-linked linked-runtime-cap
mv "$runtime_host/plugins/runtime-linked/run" "$TEST_DIR/runtime-outside"
ln -s "$TEST_DIR/runtime-outside" "$runtime_host/plugins/runtime-linked/run"
if TOOLKIT_ROOT="$runtime_toolkit" CC_HOST_HOME="$runtime_host" cc_plugin_run runtime-linked operation >/dev/null 2>&1; then
    fail 'symlinked runtime entrypoint executed'
fi

# Calling inventory again proves runtime was not smuggled into discovery.
rm -f "$runtime_trace"
CC_PLUGIN_EXEC_TRACE="$runtime_trace" inventory "$runtime_toolkit" "$runtime_host" >/dev/null
[ ! -e "$runtime_trace" ] || fail 'discovery executed plugin code after runtime was added'

# Public plugin/capability inspection and help/switch discovery leave the
# disposable host tree byte-for-byte unchanged and emit no redirected ANSI.
public_home="$TEST_DIR/public-home" public_host="$public_home/.captaincronos/hosts/public"
mkdir -p "$public_host/plugins"; chmod 700 "$public_home" "$public_home/.captaincronos" "$public_home/.captaincronos/hosts" "$public_host" "$public_host/plugins"
make_plugin "$public_host/plugins" public-plugin public-cap
fingerprint() { find "$public_home" -mindepth 1 -printf '%P|%y|%m|%s|%T@|%l\n' | LC_ALL=C sort; }
fingerprint > "$TEST_DIR/before"
for spec in 'plugin' 'plugin list' 'plugin status' 'capability' 'capability list' 'capability check public-cap' 'plugin --help' 'capability --help' 'plugin switches' 'capability switches'; do
    read -r -a args <<< "$spec"
    output="$(env HOME="$public_home" CC_HOME="$public_home/.captaincronos" CC_HOST_HOME="$public_host" NO_COLOR=1 TERM=dumb CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" bash "$PROJECT_ROOT/tools/cc" "${args[@]}")" \
        || fail "public zero-write command failed: cc $spec"
    if printf '%s\n' "$output" | grep -q $'\033'; then fail "redirected ANSI leaked: cc $spec"; fi
done
fingerprint > "$TEST_DIR/after"
cmp -s "$TEST_DIR/before" "$TEST_DIR/after" || fail 'plugin/capability discovery mutated host state'

printf 'Plugin and capability foundation tests: PASS\n'
