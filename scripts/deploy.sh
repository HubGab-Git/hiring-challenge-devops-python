#!/usr/bin/env bash
set -euo pipefail

TARGET=${DEPLOY_TARGET:-local}

if [[ "$TARGET" == "local" ]]; then
  docker compose up -d --build
  echo "Local deployment is up at http://localhost:8000"
  exit 0
fi

if [[ "$TARGET" != "aws" ]]; then
  echo "Unknown DEPLOY_TARGET: $TARGET (use 'local' or 'aws')" >&2
  exit 1
fi

: "${AWS_REGION:?Missing AWS_REGION}"
: "${AWS_ACCOUNT_ID:?Missing AWS_ACCOUNT_ID}"
: "${ECR_REPO:?Missing ECR_REPO}"
: "${ECS_CLUSTER:?Missing ECS_CLUSTER}"
: "${ECS_SERVICE:?Missing ECS_SERVICE}"
: "${DATABASE_URL:?Missing DATABASE_URL}"
: "${EXECUTION_ROLE_ARN:?Missing EXECUTION_ROLE_ARN}"
: "${TASK_ROLE_ARN:?Missing TASK_ROLE_ARN}"

IMAGE_TAG=${IMAGE_TAG:-$(git rev-parse --short HEAD 2>/dev/null || date +%s)}
IMAGE_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG"
export IMAGE_URI

aws ecr describe-repositories --repository-names "$ECR_REPO" >/dev/null 2>&1 \
  || aws ecr create-repository --repository-name "$ECR_REPO" >/dev/null

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin \
  "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

docker build -t "$IMAGE_URI" .
docker push "$IMAGE_URI"

python - <<'PY'
import json
import os
from pathlib import Path

path = Path("deploy/aws/task-def.json")
raw = path.read_text()
raw = raw.replace("__IMAGE__", os.environ["IMAGE_URI"])
raw = raw.replace("__DATABASE_URL__", os.environ["DATABASE_URL"])
raw = raw.replace("__EXECUTION_ROLE_ARN__", os.environ["EXECUTION_ROLE_ARN"])
raw = raw.replace("__TASK_ROLE_ARN__", os.environ["TASK_ROLE_ARN"])
print(raw)
PY > /tmp/task-def.json

aws ecs register-task-definition --cli-input-json file:///tmp/task-def.json >/tmp/task-def-out.json

REVISION=$(python - <<'PY'
import json
with open('/tmp/task-def-out.json') as f:
    print(json.load(f)['taskDefinition']['revision'])
PY
)

aws ecs update-service \
  --cluster "$ECS_CLUSTER" \
  --service "$ECS_SERVICE" \
  --task-definition "inventory-api:$REVISION" \
  --force-new-deployment

echo "AWS deployment updated: $ECS_CLUSTER/$ECS_SERVICE"
