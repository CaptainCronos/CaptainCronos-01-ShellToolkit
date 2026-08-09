#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-data.sh"
source "$PROJECT_ROOT/lib/cc-yaml.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

TEST_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

write_config() {
    local destination="$1" json_program="$2" yaml_program="$3"
    sed \
        -e "s/CC_JSON=\"jq\"/CC_JSON=\"$json_program\"/" \
        -e "s/CC_YAML=\"yq\"/CC_YAML=\"$yaml_program\"/" \
        "$PROJECT_ROOT/config/programs.conf" > "$destination"
}

REAL_JQ="$(command -v jq)"
REAL_YQ="$(command -v yq)"
[ -n "$REAL_JQ" ] || fail "jq is unavailable"
[ -n "$REAL_YQ" ] || fail "yq is unavailable"

[ "$(cc_program_get json)" = "jq" ] || fail "JSON capability did not resolve to jq"
[ "$(cc_program_get yaml)" = "yq" ] || fail "YAML capability did not resolve to yq"
[ "$(cc_program_status json)" = "OK" ] || fail "configured jq was not compatible"
[ "$(cc_program_status yaml)" = "OK" ] || fail "supported yq did not report OK"
case "$(yq --version 2>&1)" in
    yq\ [0-9]*) ;;
    *) fail "installed yq did not identify as the Kislyuk implementation" ;;
esac

cat > "$TEST_DIR/valid.json" <<'EOF_JSON'
{"name":"cronos","nested":{"enabled":true},"count":2}
EOF_JSON
printf '%s\n' '{"name":' > "$TEST_DIR/malformed.json"
_cc_json_validate "$TEST_DIR/valid.json" || fail "valid JSON failed validation"
if _cc_json_validate "$TEST_DIR/malformed.json"; then
    fail "malformed JSON passed validation"
fi
[ "$(_cc_json_query '.nested' "$TEST_DIR/valid.json")" = $'{\n  "enabled": true\n}' ] || fail "structured JSON query output changed"
[ "$(_cc_json_query_raw '.name' "$TEST_DIR/valid.json")" = "cronos" ] || fail "raw JSON query output changed"
# This is a jq expression, not a shell expression.
# shellcheck disable=SC2016
generated_json="$(_cc_json_generate '{name: $name, count: $count, content: $content}' --compact-output --arg name cronos --argjson count 2 --arg content $'line 1\nline "2"')"
printf '%s\n' "$generated_json" | _cc_json_validate || fail "generated JSON was invalid"
[ "$(printf '%s\n' "$generated_json" | _cc_json_query_raw '.count | type')" = "number" ] || fail "generated JSON number semantics changed"
[ "$(printf '%s\n' "$generated_json" | _cc_json_query_raw '.content')" = $'line 1\nline "2"' ] || fail "generated JSON escaping changed content"

cat > "$TEST_DIR/valid.yaml" <<'EOF_YAML'
name: cronos
nested:
  enabled: true
count: 2
quoted: "true"
EOF_YAML
printf '%s\n' 'name: [' > "$TEST_DIR/malformed.yaml"
_cc_yaml_validate "$TEST_DIR/valid.yaml" || fail "valid YAML failed validation"
if _cc_yaml_validate "$TEST_DIR/malformed.yaml"; then
    fail "malformed YAML passed validation"
fi
[ "$(_cc_yaml_query_raw '.name' "$TEST_DIR/valid.yaml")" = "cronos" ] || fail "raw YAML query output changed"
[ "$(_cc_yaml_query '.nested' "$TEST_DIR/valid.yaml")" = $'{\n  "enabled": true\n}' ] || fail "structured YAML query output changed"
[ "$(_cc_yaml_query_raw '.quoted | type' "$TEST_DIR/valid.yaml")" = "string" ] || fail "quoted YAML scalar lost string semantics"

_cc_yaml_set_string "$TEST_DIR/valid.yaml" quoted "false"
_cc_yaml_set_nested_string "$TEST_DIR/valid.yaml" location bay "B-01"
[ "$(_cc_yaml_query_raw '.quoted | type' "$TEST_DIR/valid.yaml")" = "string" ] || fail "YAML mutation changed a string into a boolean"
grep -q '^quoted: "false"$' "$TEST_DIR/valid.yaml" || fail "YAML mutation did not preserve quoted style"
[ "$(_cc_yaml_query_raw '.count | type' "$TEST_DIR/valid.yaml")" = "number" ] || fail "YAML mutation changed an existing number"
[ "$(cc_yaml_get_nested "$TEST_DIR/valid.yaml" location bay)" = "B-01" ] || fail "semantic nested YAML lookup failed"

MARKER="$TEST_DIR/executed"
cat > "$TEST_DIR/data.json" <<EOF_DATA
{"value":"\$(touch $MARKER)"}
EOF_DATA
[ "$(_cc_json_query_raw '.value' "$TEST_DIR/data.json")" = "\$(touch $MARKER)" ] || fail "JSON data output changed"
[ ! -e "$MARKER" ] || fail "JSON data was executed as shell code"
unsafe_expression=".value; touch $MARKER"
if _cc_json_query "$unsafe_expression" "$TEST_DIR/data.json" >/dev/null 2>&1; then
    fail "invalid JSON expression unexpectedly succeeded"
fi
if _cc_json_query '--version' "$TEST_DIR/data.json" >/dev/null 2>&1; then
    fail "expression was interpreted as a processor option"
fi
[ ! -e "$MARKER" ] || fail "JSON expression was evaluated by the shell"

literal_key="key\"] | touch $MARKER | .[\""
_cc_yaml_set_string "$TEST_DIR/valid.yaml" "$literal_key" "literal"
[ "$(_cc_yaml_get_string "$TEST_DIR/valid.yaml" "$literal_key")" = "literal" ] || fail "YAML key arguments were not preserved"
[ ! -e "$MARKER" ] || fail "YAML key data was executed as shell code"

_cc_yaml_write_map "$TEST_DIR/generated.yaml" \
    name cronos \
    boolean-looking true \
    null-looking null \
    command-looking "\$(touch $MARKER)"
_cc_yaml_validate "$TEST_DIR/generated.yaml" || fail "generated YAML was invalid"
[ "$(_cc_yaml_query_raw '."boolean-looking" | type' "$TEST_DIR/generated.yaml")" = "string" ] || fail "generated YAML string semantics changed"
[ ! -e "$MARKER" ] || fail "generated YAML data was executed as shell code"

ln -s "$REAL_JQ" "$TEST_DIR/json-alt"
ln -s "$REAL_YQ" "$TEST_DIR/yaml-alt"
cat > "$TEST_DIR/yaml-incompatible" <<'EOF_INCOMPATIBLE_YAML'
#!/usr/bin/env bash
printf '%s\n' 'yq (https://github.com/mikefarah/yq/) version v4.45.1'
EOF_INCOMPATIBLE_YAML
cat > "$TEST_DIR/json-incompatible" <<'EOF_INCOMPATIBLE_JSON'
#!/usr/bin/env bash
exit 1
EOF_INCOMPATIBLE_JSON
chmod 755 "$TEST_DIR/yaml-incompatible" "$TEST_DIR/json-incompatible"
PATH="$TEST_DIR:$PATH"
export PATH

write_config "$TEST_DIR/alternate.conf" json-alt yaml-alt
CC_PROGRAMS_CONFIG="$TEST_DIR/alternate.conf"
export CC_PROGRAMS_CONFIG
cc_program_load
[ "$(_cc_json_program)" = "json-alt" ] || fail "alternate JSON capability did not resolve"
[ "$(_cc_yaml_program)" = "yaml-alt" ] || fail "alternate YAML capability did not resolve"
[ "$(cc_program_status json)" = "OK" ] || fail "alternate compatible JSON program was rejected"
[ "$(cc_program_status yaml)" = "OK" ] || fail "alternate compatible YAML program was rejected"

write_config "$TEST_DIR/incompatible-yaml.conf" json-alt yaml-incompatible
CC_PROGRAMS_CONFIG="$TEST_DIR/incompatible-yaml.conf"
cc_program_load
[ "$(cc_program_status yaml)" = "INCOMPATIBLE" ] || fail "incompatible yq was not distinguished"
if cc_program_validate "$TEST_DIR/incompatible-yaml.conf"; then
    fail "required incompatible YAML did not fail validation"
fi
[ "$CC_PROGRAMS_INCOMPATIBLE_REQUIRED" -eq 1 ] || fail "required incompatible count was incorrect"
program_check_status=0
program_check_output="$(CC_PROGRAMS_CONFIG="$TEST_DIR/incompatible-yaml.conf" bash "$PROJECT_ROOT/tools/cc" programs check 2>&1)" || program_check_status=$?
[ "$program_check_status" -ne 0 ] || fail "program check accepted incompatible required YAML"
printf '%s\n' "$program_check_output" | grep -Eq 'YAML[[:space:]]+yaml-incompatible[[:space:]]+INCOMPATIBLE' || fail "program check did not report INCOMPATIBLE"
printf '%s\n' "$program_check_output" | grep -Eq 'Required incompatible:[[:space:]]+1' || fail "program check did not report its incompatible count"
dependency_status=0
dependency_output="$(CC_PROGRAMS_CONFIG="$TEST_DIR/incompatible-yaml.conf" bash "$PROJECT_ROOT/tools/cc" asset path 2>&1)" || dependency_status=$?
[ "$dependency_status" -eq 127 ] || fail "command dependency gate accepted incompatible YAML"
printf '%s\n' "$dependency_output" | grep -Eq '^yaml[[:space:]]+INCOMPATIBLE' || fail "dependency gate did not distinguish incompatibility"

write_config "$TEST_DIR/missing-yaml.conf" json-alt yaml-missing
CC_PROGRAMS_CONFIG="$TEST_DIR/missing-yaml.conf"
cc_program_load
[ "$(cc_program_status yaml)" = "MISSING" ] || fail "missing yq did not report MISSING"
if cc_program_validate "$TEST_DIR/missing-yaml.conf"; then
    fail "required missing YAML did not fail validation"
fi
[ "$CC_PROGRAMS_MISSING_REQUIRED" -eq 1 ] || fail "required missing count was incorrect"

write_config "$TEST_DIR/missing-json.conf" json-missing yaml-alt
CC_PROGRAMS_CONFIG="$TEST_DIR/missing-json.conf"
cc_program_validate "$TEST_DIR/missing-json.conf" || fail "optional missing JSON failed validation"
[ "$CC_PROGRAMS_MISSING_OPTIONAL" -eq 1 ] || fail "optional missing count was incorrect"

write_config "$TEST_DIR/incompatible-json.conf" json-incompatible yaml-alt
CC_PROGRAMS_CONFIG="$TEST_DIR/incompatible-json.conf"
cc_program_validate "$TEST_DIR/incompatible-json.conf" || fail "optional incompatible JSON failed validation"
[ "$CC_PROGRAMS_INCOMPATIBLE_OPTIONAL" -eq 1 ] || fail "optional incompatible count was incorrect"

printf 'Structured-data tests: PASS\n'
