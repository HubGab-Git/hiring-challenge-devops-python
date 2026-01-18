#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:=us-east-1}"
: "${PROJECT_NAME:=inventory}"
: "${DB_USERNAME:=inventory}"
: "${ACM_CERT_ARN:=}"
: "${API_DOMAIN_NAME:=}"
: "${ROUTE53_ZONE_ID:=}"
: "${DB_ENGINE_VERSION:=}"
: "${DESIRED_COUNT:=1}"

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TF_DIR="$ROOT_DIR/deploy/aws/terraform"

base_tag=$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || true)
if [[ -z "$base_tag" ]]; then
  base_tag=$(date +%s)
fi
IMAGE_TAG=${IMAGE_TAG:-${base_tag}-$(date +%s)}

if [[ -z "$ACM_CERT_ARN" ]]; then
  echo "Warning: ACM_CERT_ARN not set; ALB will run HTTP only."
fi

pushd "$TF_DIR" >/dev/null
terraform init
ECR_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || true)
popd >/dev/null

CLUSTER_NAME="${PROJECT_NAME}-cluster"
SERVICE_NAME="${PROJECT_NAME}-service"
ECR_REPO="${PROJECT_NAME}-api"

repo_exists=0
if aws ecr describe-repositories --repository-names "$ECR_REPO" >/dev/null 2>&1; then
  repo_exists=1
fi

service_status=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" \
  --query 'services[0].status' --output text 2>/dev/null || true)
service_exists=0
if [[ "$service_status" == "ACTIVE" ]]; then
  service_exists=1
fi

if [[ "$repo_exists" -eq 0 ]]; then
  echo "ECR repo not found; provisioning infra first."
  pushd "$TF_DIR" >/dev/null
  terraform apply -auto-approve \
    -var="aws_region=$AWS_REGION" \
    -var="project_name=$PROJECT_NAME" \
    -var="db_username=$DB_USERNAME" \
    -var="db_engine_version=$DB_ENGINE_VERSION" \
    -var="acm_certificate_arn=$ACM_CERT_ARN" \
    -var="api_domain_name=$API_DOMAIN_NAME" \
    -var="route53_zone_id=$ROUTE53_ZONE_ID" \
    -var="image_tag=$IMAGE_TAG" \
    -var="desired_count=0"
  ECR_URL=$(terraform output -raw ecr_repository_url)
  popd >/dev/null
fi

IMAGE_URI="$ECR_URL:$IMAGE_TAG"

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "${ECR_URL%/*}"

docker buildx build --platform linux/amd64 -t "$IMAGE_URI" --push "$ROOT_DIR"

pushd "$TF_DIR" >/dev/null
terraform apply -auto-approve \
  -var="aws_region=$AWS_REGION" \
  -var="project_name=$PROJECT_NAME" \
  -var="db_username=$DB_USERNAME" \
  -var="db_engine_version=$DB_ENGINE_VERSION" \
  -var="acm_certificate_arn=$ACM_CERT_ARN" \
  -var="api_domain_name=$API_DOMAIN_NAME" \
  -var="route53_zone_id=$ROUTE53_ZONE_ID" \
  -var="image_tag=$IMAGE_TAG" \
  -var="desired_count=$DESIRED_COUNT"
popd >/dev/null

if [[ "$service_exists" -eq 1 ]]; then
  echo "Waiting for ECS service to become stable..."
  aws ecs wait services-stable --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME"
  tg_arn=$(aws elbv2 describe-target-groups --names "${PROJECT_NAME}-tg" \
    --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || true)
  if [[ -n "$tg_arn" ]]; then
    echo "Waiting for target group to be healthy..."
    aws elbv2 wait target-in-service --target-group-arn "$tg_arn"
  fi
fi

API_URL=$(terraform -chdir="$TF_DIR" output -raw api_url)
echo "Deployment complete. API URL: $API_URL"

if [[ -n "$API_URL" ]]; then
  API_URL="$API_URL" "$ROOT_DIR/scripts/aws_smoke_test.sh"
fi
