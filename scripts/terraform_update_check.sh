#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TF_DIR="$ROOT_DIR/deploy/aws/terraform"

pushd "$TF_DIR" >/dev/null
terraform init -upgrade
terraform providers lock -platform=linux_amd64 -platform=darwin_amd64 -platform=darwin_arm64
terraform providers
popd >/dev/null
