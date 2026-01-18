#!/usr/bin/env bash
set -euo pipefail

python -m pip install -r requirements-dev.txt

python -m ruff check app cli tests
python -m bandit -r app cli
python -m pip_audit -r requirements.txt

docker run --rm -i hadolint/hadolint < Dockerfile

docker run --rm -v "$(pwd)":/src aquasec/trivy:latest \
  fs --exit-code 1 --severity HIGH,CRITICAL /src
