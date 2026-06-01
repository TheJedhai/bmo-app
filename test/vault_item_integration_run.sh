#!/usr/bin/env bash
# ============================================================================
# Vault item E2E integration test runner
# ============================================================================
# Starts a disposable bmo-server instance with a TEMPORARY database and blob
# directory, runs the Flutter test, then tears down the server and temp files.
#
# NEVER runs against production — the DB and blob dir are scratch paths that
# are deleted after the test.
#
# Usage:
#   chmod +x test/vault_item_integration_run.sh
#   ./test/vault_item_integration_run.sh
# ============================================================================

set -euo pipefail

VENV_PY="$HOME/Library/Application Support/BMO/venv/bin/python"
TEST_PORT=8090

echo "=== Vault Item E2E Test Runner ==="

# -- Create temp paths --------------------------------------------------------
export BMO_TEST_DB
BMO_TEST_DB=$(mktemp /tmp/bmo-e2e-items-XXXXXX.db)
echo "[1/5] Temp DB: $BMO_TEST_DB"

export BMO_TEST_BLOBS
BMO_TEST_BLOBS=$(mktemp -d /tmp/bmo-e2e-blobs-items-XXXXXX)
echo "       Temp blob dir: $BMO_TEST_BLOBS"

# -- Start disposable server --------------------------------------------------
echo "[2/5] Starting disposable bmo-server on port $TEST_PORT ..."
BMO_DB_PATH="$BMO_TEST_DB" \
BMO_VAULT_BLOB_DIR="$BMO_TEST_BLOBS" \
BMO_HOST="127.0.0.1" \
  "$VENV_PY" -m uvicorn bmo_server.main:app \
    --port "$TEST_PORT" \
    --host 127.0.0.1 \
    --log-level warning &
SERVER_PID=$!

# -- Wait for server to be healthy --------------------------------------------
echo "[3/5] Waiting for server to be healthy ..."
for i in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:$TEST_PORT/health" >/dev/null 2>&1; then
    echo "       Server is up (PID=$SERVER_PID)."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: Server failed to start within 30 seconds."
    kill "$SERVER_PID" 2>/dev/null || true
    exit 1
  fi
  sleep 0.5
done

# -- Run the Flutter test -----------------------------------------------------
echo "[4/5] Running Flutter integration test ..."
set +e
BMO_SERVER_URL="http://127.0.0.1:$TEST_PORT" \
  flutter test --platform=chrome test/vault_item_integration_test.dart
TEST_EXIT=$?
set -e

# -- Tear down ----------------------------------------------------------------
echo "[5/5] Tearing down ..."
kill "$SERVER_PID" 2>/dev/null || true
wait "$SERVER_PID" 2>/dev/null || true
rm -f "$BMO_TEST_DB"
rm -rf "$BMO_TEST_BLOBS"
echo "       Server stopped, temp files removed."

# -- Report -------------------------------------------------------------------
if [ "$TEST_EXIT" -eq 0 ]; then
  echo "=== E2E test PASSED ==="
else
  echo "=== E2E test FAILED (exit code: $TEST_EXIT) ==="
fi
exit $TEST_EXIT
