#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TF_DIR="$ROOT_DIR/deploy/aws/terraform"

pushd "$TF_DIR" >/dev/null
terraform fmt -check
terraform validate
popd >/dev/null

# Static security scans (free/open-source) via containers

docker run --rm -v "$TF_DIR":/src aquasec/tfsec:latest /src

docker run --rm -v "$TF_DIR":/src bridgecrew/checkov:latest \
  --directory /src --quiet
