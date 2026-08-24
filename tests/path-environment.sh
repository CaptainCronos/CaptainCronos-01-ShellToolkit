#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_DIR="$(mktemp -d)"

cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    local file="$1" expected="$2" label="$3"
    grep -Fq -- "$expected" "$file" || fail "$label"
}

assert_not_contains() {
    local file="$1" unexpected="$2" label="$3"
    ! grep -Fq -- "$unexpected" "$file" || fail "$label"
}

path_count() {
    local path_value="$1" needle="$2"
    HOME="$TEST_HOME" bash -c 'source "$1/lib/cc-path.sh"; cc_path_count_entry "$2" "$3"' \
        bash "$PROJECT_ROOT" "$path_value" "$needle"
}

repair() {
    HOME="$TEST_HOME" PATH="$TEST_PATH" CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" \
        bash "$PROJECT_ROOT/tools/commands/env" path --fix >/dev/null 2>&1
}

source_path() {
    local initial_path="$1" count="${2:-1}"
    HOME="$TEST_HOME" PATH="$initial_path" bash --noprofile --norc -c '
        set -e
        for ((index = 0; index < $1; index++)); do source "$HOME/.bashrc"; done
        printf "%s\n" "$PATH"
    ' bash "$count"
}

new_home() {
    TEST_HOME="$TEST_DIR/$1"
    mkdir -p "$TEST_HOME"
    TEST_PATH="$TEST_HOME/bin:$TEST_HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
}

# Clean canonical startup files remain byte-for-byte stable on repair.
new_home clean
mkdir -p "$TEST_HOME/bin" "$TEST_HOME/.local/bin"
cp "$PROJECT_ROOT/bash/bashrc" "$TEST_HOME/.bashrc"
before_hash="$(sha256sum "$TEST_HOME/.bashrc")"
repair
[ "$(sha256sum "$TEST_HOME/.bashrc")" = "$before_hash" ] || fail 'clean canonical bashrc changed during repair'

# Reproduced HOME/bin and equivalent local/literal legacy forms are normalized.
new_home legacy
mkdir -p "$TEST_HOME/bin" "$TEST_HOME/.local/bin" "$TEST_HOME/custom/bin"
cat > "$TEST_HOME/.bashrc" <<EOF_LEGACY
# unrelated-before
[ -d "\$HOME/bin" ] && export PATH="\$HOME/bin:\$PATH"
test   -d   "\${HOME}/.local/bin"   &&   export PATH="\${HOME}/.local/bin:\${PATH}"
[ -d "$TEST_HOME/bin" ] && export PATH="$TEST_HOME/bin:\$PATH"
case ":\$PATH:" in *":\$HOME/custom/bin:"*) ;; *) export PATH="\$HOME/custom/bin:\$PATH" ;; esac
# unrelated-after
EOF_LEGACY
legacy_inspection="$(HOME="$TEST_HOME" PATH="$TEST_PATH" CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" \
    bash "$PROJECT_ROOT/tools/commands/env" path)" || fail 'legacy inspection failed'
printf '%s\n' "$legacy_inspection" | grep -Fq '3 known legacy writer(s)' \
    || fail 'known startup conflicts were not reported'
repair
# Literal startup syntax is the assertion target.
# shellcheck disable=SC2016
assert_not_contains "$TEST_HOME/.bashrc" '[ -d "$HOME/bin" ] && export PATH="$HOME/bin:$PATH"' \
    'reproduced legacy HOME/bin line survived repair'
# shellcheck disable=SC2016
assert_not_contains "$TEST_HOME/.bashrc" 'test   -d   "${HOME}/.local/bin"' \
    'legacy local/bin quote variation survived repair'
assert_not_contains "$TEST_HOME/.bashrc" "[ -d \"$TEST_HOME/bin\" ]" \
    'literal-home legacy line survived repair'
assert_contains "$TEST_HOME/.bashrc" '# unrelated-before' 'unrelated prefix was lost'
# shellcheck disable=SC2016
assert_contains "$TEST_HOME/.bashrc" 'export PATH="$HOME/custom/bin:$PATH"' 'custom PATH addition was lost'
assert_contains "$TEST_HOME/.bashrc" '# unrelated-after' 'unrelated suffix was lost'
[ "$(grep -Fc '# Captain Cronos managed PATH: begin' "$TEST_HOME/.bashrc")" -eq 1 ] \
    || fail 'repair did not install exactly one canonical block'

# Five repeated source operations normalize only managed entries and are stable.
nvm="$TEST_HOME/.nvm/versions/node/v20.18.3/bin"
initial="$nvm:$TEST_HOME/bin:/opt/custom:$TEST_HOME/bin:/usr/bin:$TEST_HOME/.local/bin:$TEST_HOME/.local/bin"
once="$(source_path "$initial" 1)"
five="$(source_path "$initial" 5)"
[ "$once" = "$five" ] || fail 'five repeated sources changed canonical PATH'
[ "$(path_count "$five" "$TEST_HOME/bin")" -eq 1 ] || fail 'HOME/bin was not unique after five sources'
[ "$(path_count "$five" "$TEST_HOME/.local/bin")" -eq 1 ] || fail '.local/bin was not unique after five sources'
case "$five" in
    "$TEST_HOME/custom/bin:$nvm:$TEST_HOME/bin:/opt/custom:/usr/bin:$TEST_HOME/.local/bin") ;;
    *) fail 'NVM, custom, or unrelated PATH ordering changed unexpectedly' ;;
esac

# A fresh interactive shell reaches the same canonical PATH.
fresh="$(HOME="$TEST_HOME" PATH="$initial" bash --noprofile --rcfile "$TEST_HOME/.bashrc" -i -c \
    'printf "%s\n" "$PATH"' 2>/dev/null)"
[ "$fresh" = "$once" ] || fail 'fresh interactive shell PATH differs from repaired source result'

# Guarded profile insertion after bashrc does not duplicate managed entries.
cat > "$TEST_HOME/.profile" <<'EOF_PROFILE'
source "$HOME/.bashrc"
case ":$PATH:" in *":$HOME/bin:"*) ;; *) PATH="$HOME/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
export PATH
EOF_PROFILE
profile_path="$(HOME="$TEST_HOME" PATH="/usr/bin:/bin" bash --noprofile --norc -c \
    'source "$HOME/.profile"; printf "%s\n" "$PATH"')"
[ "$(path_count "$profile_path" "$TEST_HOME/bin")" -eq 1 ] || fail '.profile duplicated HOME/bin'
[ "$(path_count "$profile_path" "$TEST_HOME/.local/bin")" -eq 1 ] || fail '.profile duplicated .local/bin'

# Historical absolute guards are removed and replaced by the canonical block.
new_home guards
mkdir -p "$TEST_HOME/bin" "$TEST_HOME/.local/bin"
cat > "$TEST_HOME/.bashrc" <<EOF_GUARDS
# keep-start

# Captain Cronos PATH guard: home bin
case ":\$PATH:" in
    *":$TEST_HOME/bin:"*) ;;
    *) export PATH="$TEST_HOME/bin:\$PATH" ;;
esac

# Captain Cronos PATH guard: local bin
case ":\$PATH:" in
    *":$TEST_HOME/.local/bin:"*) ;;
    *) export PATH="$TEST_HOME/.local/bin:\$PATH" ;;
esac
# keep-end
EOF_GUARDS
repair
assert_not_contains "$TEST_HOME/.bashrc" '# Captain Cronos PATH guard:' 'historical guard survived repair'
assert_contains "$TEST_HOME/.bashrc" '# keep-start' 'guard repair lost leading content'
assert_contains "$TEST_HOME/.bashrc" '# keep-end' 'guard repair lost trailing content'

# Ambiguous user-owned PATH logic is reported, preserved, and safely normalized
# because the canonical block is relocated to the end of the startup file.
new_home ambiguous
mkdir -p "$TEST_HOME/bin" "$TEST_HOME/.local/bin"
cat > "$TEST_HOME/.bashrc" <<'EOF_AMBIGUOUS'
export PATH="$PATH:$HOME/bin"
export PATH="$HOME/custom:$PATH"
EOF_AMBIGUOUS
ambiguous_output="$(HOME="$TEST_HOME" PATH="$TEST_PATH" CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" \
    bash "$PROJECT_ROOT/tools/commands/env" path --fix 2>&1)" || fail 'ambiguous repair failed'
# shellcheck disable=SC2016
assert_contains "$TEST_HOME/.bashrc" 'export PATH="$PATH:$HOME/bin"' 'ambiguous PATH statement was deleted'
printf '%s\n' "$ambiguous_output" | grep -Fq 'ambiguous PATH line(s) were preserved' \
    || fail 'ambiguous PATH statement was not reported'
ambiguous_path="$(source_path "/usr/bin:/bin" 5)"
[ "$(path_count "$ambiguous_path" "$TEST_HOME/bin")" -eq 1 ] || fail 'ambiguous line defeated HOME/bin normalization'
[ "$(path_count "$ambiguous_path" "$TEST_HOME/.local/bin")" -eq 1 ] || fail 'ambiguous line defeated local/bin normalization'
case "$ambiguous_path" in *"$TEST_HOME/custom"*) ;; *) fail 'custom PATH addition did not survive sourcing' ;; esac

# A second repair is a true no-op: content, identity, mode, and timestamp stay stable.
repair
second_state="$(stat -c '%d:%i:%a:%Y:%s' "$TEST_HOME/.bashrc") $(sha256sum "$TEST_HOME/.bashrc")"
repair
[ "$(stat -c '%d:%i:%a:%Y:%s' "$TEST_HOME/.bashrc") $(sha256sum "$TEST_HOME/.bashrc")" = "$second_state" ] \
    || fail 'second repair changed an already canonical file'

# Existing permissions are preserved.
chmod 0640 "$TEST_HOME/.bashrc"
repair
[ "$(stat -c %a "$TEST_HOME/.bashrc")" = 640 ] || fail 'repair changed existing shell-file permissions'

# Inspection is zero-write, even when startup configuration needs repair.
new_home inspect
printf '%s\n' '# inspection fixture' > "$TEST_HOME/.bashrc"
inspect_state="$(stat -c '%d:%i:%a:%Y:%s' "$TEST_HOME/.bashrc") $(sha256sum "$TEST_HOME/.bashrc")"
inspect_tree_before="$(find "$TEST_HOME" -printf '%P:%y:%m:%s\n' | sort)"
for inspect_action in summary path; do
    inspect_args=()
    [ "$inspect_action" = summary ] || inspect_args=(path)
    HOME="$TEST_HOME" PATH="/usr/bin:/bin" CAPTAIN_CRONOS_TOOLKIT_ROOT="$PROJECT_ROOT" \
        bash "$PROJECT_ROOT/tools/commands/env" "${inspect_args[@]}" >/dev/null 2>&1 \
        && fail "missing managed PATH unexpectedly passed $inspect_action inspection"
done
[ "$(stat -c '%d:%i:%a:%Y:%s' "$TEST_HOME/.bashrc") $(sha256sum "$TEST_HOME/.bashrc")" = "$inspect_state" ] \
    || fail 'read-only PATH inspection changed .bashrc'
[ "$(find "$TEST_HOME" -printf '%P:%y:%m:%s\n' | sort)" = "$inspect_tree_before" ] \
    || fail 'read-only environment inspection changed the fixture home'
[ ! -e "$TEST_HOME/bin" ] && [ ! -e "$TEST_HOME/.local" ] \
    || fail 'read-only PATH inspection created managed directories'

# Repair failures are nonzero and symlink targets are never followed.
new_home unsafe
printf '%s\n' 'external target' > "$TEST_DIR/external-bashrc"
ln -s "$TEST_DIR/external-bashrc" "$TEST_HOME/.bashrc"
if repair 2>/dev/null; then fail 'repair accepted a symlinked .bashrc'; fi
[ "$(cat "$TEST_DIR/external-bashrc")" = 'external target' ] || fail 'symlink target was modified'

new_home malformed
cat > "$TEST_HOME/.bashrc" <<'EOF_MALFORMED'
# content that must survive
# Captain Cronos managed PATH: end
EOF_MALFORMED
malformed_before="$(sha256sum "$TEST_HOME/.bashrc")"
if repair 2>/dev/null; then fail 'repair accepted a malformed managed block'; fi
[ "$(sha256sum "$TEST_HOME/.bashrc")" = "$malformed_before" ] || fail 'malformed repair truncated .bashrc'

# The installer/default/init sources cannot recreate the historical writer.
for source_file in bash/bashrc defaults/v1/bashrc install/install.sh tools/commands/init; do
    # This search target is literal historical shell syntax.
    # shellcheck disable=SC2016
    ! grep -Fq '[ -d "$HOME/bin" ] && export PATH="$HOME/bin:$PATH"' "$PROJECT_ROOT/$source_file" \
        || fail "$source_file can recreate the reproduced legacy writer"
done

printf 'PATH environment tests: PASS\n'
