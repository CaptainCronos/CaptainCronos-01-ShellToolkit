#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-context.sh"
cc_context_init "$PROJECT_ROOT" "$PROJECT_ROOT"
source "$PROJECT_ROOT/lib/cc-common.sh"
source "$PROJECT_ROOT/lib/cc-metadata.sh"
source "$PROJECT_ROOT/lib/cc-help.sh"

TEST_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_contains() {
    local file="$1" expected="$2" label="$3"
    grep -Fq -- "$expected" "$file" || fail "$label"
}
run_cc() { CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" bash "$PROJECT_ROOT/tools/cc" "$@"; }
assert_success() {
    local label="$1"
    shift
    if ! "$@" >"$TEST_DIR/output" 2>"$TEST_DIR/error"; then
        fail "$label: $(tr '\n' ' ' <"$TEST_DIR/error")"
    fi
}
assert_usage_error() {
    local label="$1"
    shift
    set +e
    "$@" >"$TEST_DIR/output" 2>"$TEST_DIR/error"
    local status=$?
    set -e
    [ "$status" -eq 2 ] || fail "$label (status $status, expected 2)"
}

# Required operator discovery surfaces.
for spec in \
    'install switches' \
    'system-update switches' \
    'doctor switches' \
    'kernel switches' \
    'kernel cleanup switches' \
    'env path switches'; do
    read -r -a args <<< "$spec"
    assert_success "cc $spec failed" run_cc "${args[@]}"
    assert_contains "$TEST_DIR/output" "Command: cc ${spec% switches}" "cc $spec used the wrong context"
    assert_contains "$TEST_DIR/output" 'Switches:' "cc $spec omitted switch heading"
done

assert_success 'flat no-switch contract failed' run_cc about switches
assert_contains "$TEST_DIR/output" 'No command-specific switches.' 'flat command did not state that it has no specific switches'
assert_success 'namespace contract failed' run_cc kernel switches
assert_contains "$TEST_DIR/output" 'Subcommands:' 'namespace omitted subcommands'
assert_contains "$TEST_DIR/output" 'cc kernel <subcommand> switches' 'namespace omitted nested discovery guidance'
assert_success 'mutation contract failed' run_cc system-update switches
assert_contains "$TEST_DIR/output" '--dry-run' 'mutation preview switch was absent'
assert_contains "$TEST_DIR/output" 'without persistent mutation. [default]' 'dry-run safety/default description drifted'
assert_contains "$TEST_DIR/output" '--apply' 'mutation authorization switch was absent'
assert_success 'value switch contract failed' run_cc docs switches
assert_contains "$TEST_DIR/output" '--out DIR' 'value-taking switch label was absent'

# Compatible help forms remain available; nested help now uses the narrowest
# context while command-owned top-level help remains intact.
for spec in 'install --help' 'install -h' 'kernel help' 'storage help' 'kernel cleanup --help'; do
    read -r -a args <<< "$spec"
    assert_success "existing help form failed: cc $spec" run_cc "${args[@]}"
done
assert_contains "$TEST_DIR/output" 'Command: cc kernel cleanup' 'nested --help was not contextual'

# Contextual diagnostics preserve usage status and distinguish token classes.
assert_usage_error 'unknown long switch was not a usage error' run_cc system-update --bogus
assert_contains "$TEST_DIR/error" '[CC ERROR] Unknown switch: --bogus' 'unknown long switch diagnostic drifted'
assert_contains "$TEST_DIR/error" 'Command: cc system-update' 'unknown long switch omitted context'
assert_usage_error 'unknown short switch was not a usage error' run_cc doctor -z
assert_contains "$TEST_DIR/error" '[CC ERROR] Unknown switch: -z' 'unknown short switch diagnostic drifted'
assert_usage_error 'unknown subcommand was not a usage error' run_cc kernel nonsense
assert_contains "$TEST_DIR/error" '[CC ERROR] Unknown subcommand: nonsense' 'unknown subcommand diagnostic drifted'
assert_contains "$TEST_DIR/error" 'Command: cc kernel' 'unknown subcommand used the wrong context'
assert_usage_error 'flat unknown positional was not a usage error' run_cc doctor nonsense
assert_contains "$TEST_DIR/error" '[CC ERROR] Unknown positional argument: nonsense' 'flat positional diagnostic drifted'
assert_usage_error 'nested unknown positional was not a usage error' run_cc env path nonsense
assert_contains "$TEST_DIR/error" 'Command: cc env path' 'nested positional used the wrong context'
assert_usage_error 'missing switch value was not a usage error' run_cc docs --out
assert_contains "$TEST_DIR/error" '[CC ERROR] Missing value for switch: --out' 'missing-value diagnostic drifted'
assert_contains "$TEST_DIR/error" 'Command: cc docs' 'missing-value context was absent'

# Dotted leaders remain safe for long labels, and discovery presentation remains
# ANSI-free under every non-color contract.
assert_success 'long switch-label rendering failed' run_cc repos switches
assert_contains "$TEST_DIR/output" '--bundle-dir DIR' 'long switch label was truncated'
if grep -q $'\033' "$TEST_DIR/output"; then fail 'redirected discovery contained ANSI'; fi
for environment in \
    'TERM=xterm-256color CC_COLOR_MODE=auto' \
    'TERM=xterm-256color CC_COLOR_MODE=never' \
    'NO_COLOR= TERM=xterm-256color CC_COLOR_MODE=always' \
    'TERM=dumb CC_COLOR_MODE=always'; do
    # Controlled environment fixture.
    # shellcheck disable=SC2086
    env $environment CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" \
        bash "$PROJECT_ROOT/tools/cc" repos switches >"$TEST_DIR/color"
    if grep -q $'\033' "$TEST_DIR/color"; then fail "ANSI leaked under $environment"; fi
done

# Registry/contract completeness and namespace coverage.
cc_command_list >"$TEST_DIR/registry"
cc_contract_commands | cut -d '|' -f1 | LC_ALL=C sort >"$TEST_DIR/contracts"
cmp -s "$TEST_DIR/registry" "$TEST_DIR/contracts" || fail 'registered commands and contracts differ'
[ "$(wc -l <"$TEST_DIR/contracts" | tr -d ' ')" -eq 48 ] || fail 'public command count changed unexpectedly'
[ "$(sort "$TEST_DIR/contracts" | uniq -d | wc -l | tr -d ' ')" -eq 0 ] || fail 'duplicate command contracts exist'

# Contract row selection must consume its producer completely.  Expanding the
# producer beyond pipe capacity makes an early-exit/pipefail race deterministic.
(
    command_contracts="$(cc_contract_commands)"
    subcommand_contracts="$(cc_contract_subcommands)"
    cc_contract_commands() {
        local iteration
        for ((iteration = 0; iteration < 100; iteration++)); do printf '%s\n' "$command_contracts"; done
    }
    cc_contract_subcommands() {
        local iteration
        for ((iteration = 0; iteration < 100; iteration++)); do printf '%s\n' "$subcommand_contracts"; done
    }
    command_row="$(cc_contract_command_row about)" || exit 1
    subcommand_row="$(cc_contract_subcommand_row kernel cleanup)" || exit 1
    [ "$command_row" = "$(awk -F '|' '$1 == "about" { print; exit }' <<<"$command_contracts")" ] || exit 1
    [ "$subcommand_row" = "$(awk -F '|' '$1 == "kernel" && $2 == "cleanup" { print; exit }' <<<"$subcommand_contracts")" ] || exit 1
) || fail 'contract row lookup did not drain a backpressured producer'

while IFS='|' read -r command_name class _; do
    assert_success "cc $command_name switches failed" run_cc "$command_name" switches
    if [[ "$class" == namespace* ]]; then
        cc_contract_subcommands | awk -F '|' -v command_name="$command_name" '$1 == command_name { found=1 } END { exit !found }' ||
            fail "namespace cc $command_name has no subcommands"
        assert_contains "$TEST_DIR/output" 'Subcommands:' "namespace cc $command_name did not expose subcommands"
    fi
done < <(cc_contract_commands)

while IFS='|' read -r command_name subcommand _ target; do
    assert_success "contract render failed for cc $command_name $subcommand" cc_help_render_switches "$target"
    assert_contains "$TEST_DIR/output" "Command: cc $command_name ${target#*/}" \
        "cc $command_name $subcommand resolved the wrong target"
done < <(cc_contract_subcommands)

for spec in \
    'kernel cleanup' 'kernel capabilities' 'env path' 'docs check' \
    'repos commit' 'storage workbench' 'update dev' 'verify executable'; do
    read -r -a args <<< "$spec"
    assert_success "nested dispatcher discovery failed: cc $spec switches" run_cc "${args[@]}" switches
done

duplicates="$(cc_contract_switches | cut -d '|' -f1-2 | LC_ALL=C sort | uniq -d)"
[ -z "$duplicates" ] || fail "duplicate switch contracts: $duplicates"

# Focused parser/metadata drift checks. Static presence catches advertised
# switches missing from their owning parser; explicit fixtures catch important
# accepted switches, aliases, and arity omitted from metadata. This intentionally
# does not claim full Bash parser introspection.
while IFS='|' read -r context labels arity _; do
    command_name="${context%%/*}"
    file="$PROJECT_ROOT/tools/commands/$command_name"
    IFS=',' read -r -a label_list <<< "$labels"
    for label in "${label_list[@]}"; do
        label="${label# }"
        switch_name="${label%% *}"
        grep -Fq -- "$switch_name" "$file" || fail "metadata advertises parser-absent $command_name $switch_name"
    done
done < <(cc_contract_switches)

metadata_has() {
    local context="$1" switch_name="$2" expected_arity="$3" labels arity label actual
    while IFS='|' read -r _ labels arity _; do
        IFS=',' read -r -a label_list <<< "$labels"
        for label in "${label_list[@]}"; do
            label="${label# }"
            actual="${label%% *}"
            [ "$actual" != "$switch_name" ] || { [ "$arity" = "$expected_arity" ]; return; }
        done
    done < <(cc_help_switch_rows "$context")
    return 1
}
for fixture in \
    'install --dry-run 0' 'install --apply 0' 'install --force 0' \
    'system-update --dry-run 0' 'system-update --apply 0' \
    'doctor --full 0' 'kernel/cleanup --dry-run 0' 'kernel/cleanup --apply 0' \
    'env/path --fix 0' 'env/path --apply 0' 'docs --out 1' \
    'init --host-id 1' 'repos --message 1' 'maintenance --format 1' \
    'maintenance/cleanup --dry-run 0' 'workbench --target 1'; do
    read -r context switch_name arity <<< "$fixture"
    metadata_has "$context" "$switch_name" "$arity" || fail "focused parser contract missing or wrong: $fixture"
done

# Every discovery request is intercepted before command/dependency execution.
# A disposable HOME plus mock mutation-capable programs proves zero writes and
# no mutation adapter reachability across all root and nested queries.
fixture_home="$TEST_DIR/home"
mock_bin="$TEST_DIR/bin"
trace="$TEST_DIR/mutation.trace"
mkdir -p "$fixture_home" "$mock_bin"
for program in sudo apt-get snap flatpak chmod mv install; do
    # Literal variables are evaluated by the generated mock, not this test.
    # shellcheck disable=SC2016
    printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$0 $*" >>"${CC_SWITCH_TRACE:?}"' 'exit 91' >"$mock_bin/$program"
    chmod 755 "$mock_bin/$program"
done
fingerprint() { find "$fixture_home" -mindepth 1 -printf '%P|%y|%s|%T@\n' | LC_ALL=C sort; }
fingerprint >"$TEST_DIR/before"
while read -r command_name; do
    env HOME="$fixture_home" CC_HOME="$fixture_home/.captaincronos" PATH="$mock_bin:$PATH" CC_SWITCH_TRACE="$trace" \
        CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" bash "$PROJECT_ROOT/tools/cc" \
        "$command_name" switches >/dev/null || fail "zero-write root discovery failed: $command_name"
done <"$TEST_DIR/contracts"
for spec in \
    'kernel cleanup' 'env path' 'docs check' 'repos commit' \
    'storage workbench' 'update dev' 'verify executable'; do
    read -r -a args <<< "$spec"
    env HOME="$fixture_home" CC_HOME="$fixture_home/.captaincronos" PATH="$mock_bin:$PATH" CC_SWITCH_TRACE="$trace" \
        CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" bash "$PROJECT_ROOT/tools/cc" \
        "${args[@]}" switches >/dev/null || fail "zero-write nested discovery failed: $spec"
done
fingerprint >"$TEST_DIR/after"
cmp -s "$TEST_DIR/before" "$TEST_DIR/after" || fail 'switch discovery changed the disposable HOME fingerprint'
[ ! -e "$trace" ] || fail 'switch discovery reached a mutation-capable adapter'

printf 'Command switch discovery tests: PASS\n'
