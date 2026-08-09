#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$PROJECT_ROOT/lib/cc-http.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

[ "$(cc_program_get download)" = "wget" ] || fail "download capability did not resolve to wget"
[ "$(cc_program_get http-api)" = "curl" ] || fail "HTTP/API capability did not resolve to curl"
[ "$(_cc_download_program)" = "wget" ] || fail "download helper did not select the download capability"
[ "$(_cc_http_program)" = "curl" ] || fail "HTTP helper did not select the API capability"

TEST_DIR="$(mktemp -d)"
SERVER_PID=""
cleanup() {
    if [ -n "$SERVER_PID" ]; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

PORT_FILE="$TEST_DIR/port"
python3 - "$PORT_FILE" <<'PY_SERVER' &
import http.server
import socketserver
import sys

port_file = sys.argv[1]

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def send_content(self, body, content_type="text/plain", include_body=True):
        encoded = body.encode()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("X-Test", "captain-cronos")
        self.end_headers()
        if include_body:
            self.wfile.write(encoded)

    def redirect(self):
        self.send_response(302)
        self.send_header("Location", "/file")
        self.end_headers()

    def do_GET(self):
        if self.path == "/file":
            self.send_content("download-content")
        elif self.path == "/api":
            self.send_content('{"status":"ok"}', "application/json")
        elif self.path == "/redirect":
            self.redirect()
        else:
            body = b"missing-resource"
            self.send_response(404)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    def do_HEAD(self):
        if self.path in ("/api", "/file"):
            self.send_content('{"status":"ok"}', "application/json", include_body=False)
        elif self.path == "/redirect":
            self.redirect()
        else:
            self.send_response(404)
            self.end_headers()

with socketserver.TCPServer(("127.0.0.1", 0), Handler) as server:
    with open(port_file, "w", encoding="utf-8") as handle:
        handle.write(str(server.server_address[1]))
    server.serve_forever()
PY_SERVER
SERVER_PID="$!"

for _attempt in $(seq 1 100); do
    [ -s "$PORT_FILE" ] && break
    sleep 0.05
done
[ -s "$PORT_FILE" ] || fail "local HTTP server did not start"
BASE_URL="http://127.0.0.1:$(cat "$PORT_FILE")"

_cc_download_to "$BASE_URL/file" "$TEST_DIR/file.out" 0 >/dev/null 2>&1 || fail "file download failed"
[ "$(cat "$TEST_DIR/file.out")" = "download-content" ] || fail "download content was incorrect"
_cc_download_to "$BASE_URL/redirect" "$TEST_DIR/redirect.out" 0 >/dev/null 2>&1 || fail "download redirect failed"
[ "$(cat "$TEST_DIR/redirect.out")" = "download-content" ] || fail "redirected download content was incorrect"
if _cc_download_to "$BASE_URL/missing" "$TEST_DIR/missing.out" 0 >/dev/null 2>&1; then
    fail "download helper accepted an HTTP error"
fi

[ "$(_cc_http_get "$BASE_URL/api")" = '{"status":"ok"}' ] || fail "API output was not parseable body-only data"
[ "$(_cc_http_get "$BASE_URL/redirect")" = "download-content" ] || fail "API redirect handling failed"
http_error_status=0
http_error_body="$(_cc_http_get "$BASE_URL/missing" 2>/dev/null)" || http_error_status=$?
[ "$http_error_status" -ne 0 ] || fail "HTTP helper accepted a 404 response"
[ "$http_error_body" = "missing-resource" ] || fail "HTTP error body was not preserved"
head_output="$(_cc_http_head "$BASE_URL/api")" || fail "HTTP HEAD request failed"
printf '%s\n' "$head_output" | grep -qi '^X-Test: captain-cronos' || fail "HTTP HEAD metadata was missing"
if printf '%s\n' "$head_output" | grep -q '{"status"'; then
    fail "HTTP HEAD output contained a response body"
fi
head_redirect_output="$(_cc_http_head "$BASE_URL/redirect")" || fail "HTTP HEAD redirect failed"
printf '%s\n' "$head_redirect_output" | grep -qi '^X-Test: captain-cronos' || fail "redirected HTTP HEAD metadata was missing"

dry_destination="$TEST_DIR/dry-run.out"
dry_output="$(CC_HTTP_DRY_RUN=1 _cc_download_to 'https://user:secret@example.invalid/file?token=sensitive' "$dry_destination" 3)"
[ ! -e "$dry_destination" ] || fail "download dry-run created a destination"
printf '%s\n' "$dry_output" | grep -q 'https://example.invalid/file?\[REDACTED\]' || fail "dry-run did not describe the download safely"
if printf '%s\n' "$dry_output" | grep -Eq 'secret|sensitive'; then
    fail "download dry-run exposed credentials"
fi
dry_http_output="$(CC_HTTP_DRY_RUN=1 _cc_http_get 'https://user:secret@example.invalid/api?token=sensitive')"
printf '%s\n' "$dry_http_output" | grep -q 'HTTP GET https://example.invalid/api?\[REDACTED\]' || fail "HTTP dry-run did not describe the request safely"
if printf '%s\n' "$dry_http_output" | grep -Eq 'secret|sensitive'; then
    fail "HTTP dry-run exposed credentials"
fi

TRACE_FILE="$TEST_DIR/trace"
export TRACE_FILE
sed \
    -e 's/CC_DOWNLOAD="wget"/CC_DOWNLOAD="download-mock"/' \
    -e 's/CC_HTTP_API="curl"/CC_HTTP_API="http-api-mock"/' \
    "$PROJECT_ROOT/config/programs.conf" > "$TEST_DIR/programs.conf"
cat > "$TEST_DIR/download-mock" <<'EOF_DOWNLOAD'
#!/usr/bin/env bash
printf 'download %s\n' "$*" >> "$TRACE_FILE"
EOF_DOWNLOAD
cat > "$TEST_DIR/http-api-mock" <<'EOF_HTTP'
#!/usr/bin/env bash
printf 'http %s\n' "$*" >> "$TRACE_FILE"
printf '%s\n' 'mock-api-data'
EOF_HTTP
chmod 755 "$TEST_DIR/download-mock" "$TEST_DIR/http-api-mock"
PATH="$TEST_DIR:$PATH"
export PATH
CC_PROGRAMS_CONFIG="$TEST_DIR/programs.conf"
CC_PROGRAMS_LOADED=0
export CC_PROGRAMS_CONFIG CC_PROGRAMS_LOADED

: > "$TRACE_FILE"
_cc_download_to https://example.invalid/archive.tar "$TEST_DIR/mock.out" 3
grep -q '^download --tries=4 --retry-on-http-error=408,429,500,502,503,504 --output-document=' "$TRACE_FILE" || fail "download options or capability selection were incorrect"
[ "$(_cc_http_get https://example.invalid/api)" = "mock-api-data" ] || fail "mock API output was changed"
grep -q '^http --fail-with-body --silent --show-error --location https://example.invalid/api$' "$TRACE_FILE" || fail "API options or capability selection were incorrect"
if grep -Eq -- '--no-check-certificate|--insecure|(^| )-k( |$)' "$TRACE_FILE"; then
    fail "TLS verification was disabled"
fi

printf 'HTTP interface tests: PASS\n'
