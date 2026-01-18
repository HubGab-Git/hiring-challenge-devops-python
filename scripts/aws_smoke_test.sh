#!/usr/bin/env bash
set -euo pipefail

: "${API_URL:?Missing API_URL}"

echo "Waiting for API readiness at $API_URL ..."
ready=0
for _ in {1..30}; do
  if curl -fsS "$API_URL/servers" >/dev/null; then
    ready=1
    break
  fi
  sleep 10
done

if [[ "$ready" -ne 1 ]]; then
  echo "API did not become ready in time. Check ALB target health and ECS task logs."
  exit 1
fi

echo "OK: API responded to GET /servers"
curl -fsS "$API_URL/servers" >/dev/null

suffix=$(date +%s)
payload="{\"hostname\":\"aws-smoke-$suffix\",\"ip_address\":\"10.0.9.9\",\"state\":\"active\"}"
resp_file=$(mktemp)
resp_err=$(mktemp)
trap 'rm -f "$resp_file" "$resp_err"' EXIT
status=$(curl -sS -o "$resp_file" -w "%{http_code}" -X POST "$API_URL/servers" \
  -H 'Content-Type: application/json' -d "$payload")

if [[ "$status" != "201" ]]; then
  echo "Create server failed with status $status"
  cat "$resp_file"
  exit 1
fi
echo "OK: POST /servers returned 201"

PYTHON_BIN=${PYTHON_BIN:-python3}
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  PYTHON_BIN=python
fi

id=$("$PYTHON_BIN" - <<'PY' "$resp_file" 2>"$resp_err" || true
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
print(json.loads(path.read_text())["id"])
PY
)

if [[ -z "$id" ]]; then
  echo "Create server response could not be parsed as JSON:"
  cat "$resp_file"
  if [[ -s "$resp_err" ]]; then
    echo "Parser error:"
    cat "$resp_err"
  fi
  exit 1
fi
echo "OK: created id=$id"

curl -fsS "$API_URL/servers/$id" >/dev/null
echo "OK: GET /servers/$id"
curl -fsS -X DELETE "$API_URL/servers/$id" >/dev/null
echo "OK: DELETE /servers/$id"

echo "Smoke test passed"
