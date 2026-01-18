# Instructions

You are developing an inventory management software solution for a cloud services company that provisions servers in multiple data centers. You must build a CRUD app for tracking the state of all the servers. 

Deliverables:
- PR to https://github.com/Mathpix/hiring-challenge-devops-python that includes:
- API code
- CLI code
- pytest test suite
- Working Docker Compose stack

Short API.md on how to run everything, also a short API and CLI spec

Required endpoints:
- POST /servers → create a server
- GET /servers → list all servers
- GET /servers/{id} → get one server
- PUT /servers/{id} → update server
- DELETE /servers/{id} → delete server

Requirements:
- Use FastAPI or Flask
- Store data in PostgreSQL
- Use raw SQL

Validate that:
- hostname is unique
- IP address looks like an IP

State is one of: active, offline, retired

# Project Usage

## Run with Docker Compose (default)

```bash
cp .env.example .env
# edit .env and set POSTGRES_PASSWORD
docker compose up --build
```

This starts `api` and `db`. The `tests` service runs once with verbose output and exits; it does not stop the stack. If you want the stack to stop right after tests, run:

```bash
docker compose up --build --abort-on-container-exit --exit-code-from tests
```

API is available at `http://localhost:8000`.

## CLI

```bash
python -m cli list
python -m cli get 1
python -m cli create srv-1 10.0.0.1 active
python -m cli update 1 srv-1b 10.0.0.2 offline
python -m cli delete 1
```

# Tests

Tests run automatically during `docker compose up --build`. You can also run them locally:

```bash
export DATABASE_URL=postgresql://postgres:postgres@localhost:5432/inventory
pytest
```

Note: during tests you may see a PostgreSQL "duplicate key value violates unique constraint" log entry.
This is expected and comes from the unique-hostname validation test.

# Security, Lint, and Dependency Checks

All tools below are free/open-source. Run them locally:

```bash
./scripts/security_checks.sh
```

What it checks:
- Python linting with `ruff`
- Static security analysis with `bandit`
- Dependency vulnerability scan with `pip-audit`
- Dockerfile linting with `hadolint` (via container)
- Repo vulnerability scan with `trivy` (via container)

To see outdated dependencies:

```bash
./scripts/check_updates.sh
```

# Optional AWS Deploy Switch

Default deployment is local Docker Compose. For AWS, use the deploy switch:

```bash
DEPLOY_TARGET=aws \\
AWS_REGION=us-east-1 \\
AWS_ACCOUNT_ID=123456789012 \\
ECR_REPO=inventory-api \\
ECS_CLUSTER=your-cluster \\
ECS_SERVICE=your-service \\
DATABASE_URL=postgresql://user:pass@your-rds:5432/inventory \\
EXECUTION_ROLE_ARN=arn:aws:iam::123456789012:role/ecsTaskExecutionRole \\
TASK_ROLE_ARN=arn:aws:iam::123456789012:role/ecsTaskRole \\
./scripts/deploy.sh
```

Notes:
- Requires AWS CLI, Docker, and an existing ECS cluster/service.
- Task definition template lives in `deploy/aws/task-def.json`.
- The script builds and pushes the image to ECR, then updates the ECS service.
 - This path expects an explicit `DATABASE_URL` (no Secrets Manager integration). Use the Terraform path if you want Secrets Manager + full infra provisioning.

# AWS Terraform Deployment (provision everything)

This path provisions the VPC, subnets, ALB, ECS Fargate, ECR repo, and RDS PostgreSQL via Terraform.
You only provide AWS credentials and a DB password.

Minimal (uses defaults):

```bash
./scripts/deploy_terraform_aws.sh
```

Optional overrides:

```bash
export AWS_REGION=us-east-1
export PROJECT_NAME=inventory
export DB_USERNAME=inventory
# Optional: pin Postgres engine version (otherwise latest available in region)
export DB_ENGINE_VERSION=18.1
# Optional HTTPS (requires domain + ACM certificate)
export ACM_CERT_ARN=arn:aws:acm:us-east-1:123456789012:certificate/your-cert-id
# Optional: attach a domain and create Route53 record automatically
export API_DOMAIN_NAME=api.example.com
export ROUTE53_ZONE_ID=Z1234567890
./scripts/deploy_terraform_aws.sh
```

After deploy, run a smoke test:

```bash
export API_URL=http://<alb-dns-name>
./scripts/aws_smoke_test.sh
```

Outputs are available in `deploy/aws/terraform/outputs.tf`.

Notes:
- This Terraform stack uses private subnets for ECS/RDS, NAT for egress, and a public ALB.
- If you do not provide `ACM_CERT_ARN`, the ALB runs HTTP only. When you have a domain, add ACM to enable HTTPS.
- Destroy with: `cd deploy/aws/terraform && terraform destroy`.
- The RDS password is generated randomly and stored in AWS Secrets Manager.
- ECS pulls `DATABASE_URL` directly from Secrets Manager at runtime.
- Terraform state will contain the generated secret value; store state securely (e.g., S3 + KMS).
- SSL/TLS requires a valid ACM certificate for your domain. For the automatic smoke test over HTTPS, set `API_DOMAIN_NAME` + `ROUTE53_ZONE_ID` so the script can hit a matching cert.
- RDS deletion protection and performance insights are enabled for security; disable them before `terraform destroy` if needed (cost impact).

# Terraform Security Checks

Run Terraform linting + security scans:

```bash
./scripts/terraform_security_checks.sh
```

This runs:
- `terraform fmt -check` and `terraform validate`
- `tfsec` and `checkov` via Docker for security posture checks

Notes:
- Some tfsec checks are intentionally suppressed for the public ALB and optional HTTP-only mode when ACM is not provided.

# Terraform Provider Version Check

To check for provider updates and refresh the lockfile:

```bash
./scripts/terraform_update_check.sh
```
