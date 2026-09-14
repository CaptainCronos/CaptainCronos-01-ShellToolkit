#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-containers.sh"
TEST_DIR="$(mktemp -d)"; trap 'rm -rf "$TEST_DIR"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
cat >"$TEST_DIR/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${TRACE:?}"
case "$1" in info) echo server;; ps) printf '1234567890123456\tweb\tnginx\trunning\tUp\t0.0.0.0:8080->80/tcp\n';; inspect) printf '1234567890123456\t/web\tnginx\trunning\thealthy\tdate\t0.0.0.0:8080->80/tcp\n';; logs) echo app-log;; start|stop|restart) :;; esac
EOF
cat >"$TEST_DIR/podman" <<'EOF'
#!/usr/bin/env bash
[ "$1" = info ] && exit 1
EOF
chmod 755 "$TEST_DIR/docker" "$TEST_DIR/podman"; export TRACE="$TEST_DIR/trace"; PATH="$TEST_DIR:$PATH"
providers="$(cc_container_provider_records_tsv)"; grep -q $'docker\tpresent\tusable' <<<"$providers" || fail docker
grep -q $'podman\tpresent\trestricted' <<<"$providers" || fail restricted
[ "$(cc_container_provider_select)" = docker ] || fail selection
records="$(cc_container_records_tsv docker)"; grep -q $'docker\t123456789012\tweb' <<<"$records" || fail list
show="$(cc_container_record_tsv docker web)"; ! grep -qi 'secret\|label\|env' <<<"$show" || fail leak
cc_container_logs docker web '24 hours ago' 2 >/dev/null || fail logs
if cc_container_logs docker web '' 2 >/dev/null; then fail unbounded; fi
: >"$TRACE"; cc_container_action docker start web || fail action; grep -qx 'start web' "$TRACE" || fail action-trace
grep -q sudo "$TRACE" && fail sudo
echo 'Container fixture tests: PASS'
