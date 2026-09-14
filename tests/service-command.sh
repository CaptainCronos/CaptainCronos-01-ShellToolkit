#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"; TEST_DIR="$(mktemp -d)"; trap 'rm -rf "$TEST_DIR"' EXIT
cat >"$TEST_DIR/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${TRACE:?}"
case "$1" in list-units) echo 'demo.service loaded active running demo';; show) echo loaded;; is-enabled) echo enabled;; start|stop|restart) :;; esac
EOF
cat >"$TEST_DIR/journalctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${TRACE:?}"
EOF
chmod 755 "$TEST_DIR"/*; sed -e 's/CC_SERVICE_MANAGER="systemctl"/CC_SERVICE_MANAGER="systemctl"/' "$PROJECT_ROOT/config/programs.conf" >"$TEST_DIR/programs"
export TRACE="$TEST_DIR/trace" CC_PROGRAMS_CONFIG="$TEST_DIR/programs" PATH="$TEST_DIR:$PATH"
bash "$PROJECT_ROOT/tools/cc" service start demo.service >"$TEST_DIR/out"; [ ! -s "$TRACE" ] || { echo 'FAIL dry run' >&2; exit 1; }
bash "$PROJECT_ROOT/tools/cc" service start demo.service --apply; grep -qx 'start demo.service' "$TRACE"; ! grep -q sudo "$TRACE"
echo 'Service command fixture tests: PASS'
