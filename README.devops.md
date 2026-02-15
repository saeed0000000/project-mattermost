# Mattermost DevOps Lab (AWS + Terraform + EKS + Helm + GitHub Actions)

This repository contains the **Mattermost** source code (Go backend + React webapp) **plus** a hands-on DevOps lab.

- The upstream product/readme is in `README.md` (Mattermost project documentation).
- This file (`README.devops.md`) documents **the DevOps work** done on top of the Mattermost codebase for learning and portfolio purposes.

The DevOps lab work here focuses on building and operating Mattermost in a production-shaped way on AWS, including:

- Containerization (multi-stage `Dockerfile`)
- Kubernetes packaging (Helm chart + values)
- AWS infrastructure as code (Terraform)
- CI/CD (GitHub Actions -> ECR, and a deploy workflow for EKS)
- Optional observability stack (Prometheus/Grafana + Loki/Promtail) as installable Helm values

This is a training project: the AWS infrastructure is meant to be created when needed and destroyed to control cost.

## Prerequisites

- AWS account with permissions to create EKS, VPC, RDS, ElastiCache, S3, EFS, IAM, and ECR.
- Local tools: `aws`, `terraform`, `docker`, `kubectl`, `helm`.
- GitHub repo secrets set (at minimum `AWS_ROLE_ARN`; plus `MM_DB_PASSWORD` if you use the deploy workflow).

## Current State (Important)

- The **CI build** (GitHub Actions -> ECR) works even if EKS is destroyed.
- The **deploy workflow** and Helm deploy require the EKS cluster and Kubernetes access to exist again.

## Architecture (What We Built)

Core runtime components in `eu-north-1`:

- **EKS** cluster + **managed node group** (EC2 workers)
- **Ingress** (ALB) via **AWS Load Balancer Controller** (optional, see below)
- **RDS PostgreSQL** (managed database)
- **ElastiCache Redis** (managed cache)
- **S3** (Mattermost file storage via `amazons3` driver)
- **EFS** (shared RWX storage mounted by pods)
- **ECR** (container registry for the built image)

Traffic and dependencies (high-level):

```text
User Browser -> ALB -> (Ingress) -> Service (ClusterIP) -> Mattermost Pods

Mattermost Pods -> RDS (Postgres)   [sslmode=require]
Mattermost Pods -> ElastiCache (Redis)
Mattermost Pods -> S3 (File store)  [via IRSA on the Mattermost ServiceAccount]
Mattermost Pods -> EFS (Shared storage) -> EFS Mount Targets (inside VPC)

Nodes -> NAT Gateway -> Internet Gateway -> AWS Public APIs (ECR/S3)  [no VPC Endpoints]
```

Notes:

- EKS API endpoint was configured as **public** (simplifies GitHub Actions deploy and laptop access).
- Redis is **ElastiCache** (not in-cluster) in the final design.
- Observability was prepared as code, and installed only when a cluster exists.

### Architecture Diagram (Simplified)

The architecture diagram for this lab is intentionally **high-level**. It focuses on the main flows (user traffic, CI/CD, app dependencies, and outbound egress) and omits low-level AWS details for readability.

Not shown (by design):

- Security Groups / NACLs and the detailed inbound/outbound rules.
- Route tables, per-subnet routing, and all VPC attachments.
- Exact IAM policy statements (GitHub OIDC role and IRSA roles).
- Optional hardening and production add-ons (WAF, TLS/ACM details, VPC endpoints, etc.).

Also note:

- **Observability** (Prometheus/Grafana + Loki/Promtail) exists **as code** under `helm/observability/`. It becomes part of the real runtime only after installing it on a running EKS cluster.
- **Ingress/ALB** requires AWS Load Balancer Controller; otherwise use `Service type=LoadBalancer` (see *Ingress: What’s Real vs Optional* below).

## Repo Map

- `Dockerfile`: multi-stage build (webapp + server) and minimal runtime image.
- `docker-compose.dev.yml`: local dev run (Postgres + Mattermost).
- `infra/`: Terraform for AWS (VPC, EKS, ECR, RDS, ElastiCache, S3, EFS, IAM/IRSA).
- `k8s/mattermost/`: raw Kubernetes YAMLs (used early before Helm).
- `helm/mattermost/`: Helm chart for Mattermost (and optional in-cluster Postgres/Redis).
- `helm/addons/aws-load-balancer-controller/values.yaml`: controller values (install separately).
- `helm/observability/`: install-ready values for Prometheus/Grafana and Loki/Promtail.
- `.github/workflows/build-push-ecr.yml`: CI build + push to ECR (OIDC).
- `.github/workflows/deploy-eks.yml`: manual deploy workflow (Helm upgrade to EKS).

## Project Layers (What We Practiced)

1. **Containerization**: built a reproducible image using multi-stage builds, kept runtime image small and non-root.
2. **Kubernetes Basics**: started from raw manifests in `k8s/mattermost/` (Secrets, Deployments, Services, StatefulSets).
3. **AWS Infrastructure (Terraform)**: created VPC + subnets + NAT/IGW, EKS, and managed data services (RDS/ElastiCache/S3/EFS), with remote state + locking (S3 + DynamoDB).
4. **Helm Packaging**: created `helm/mattermost/` with `values.prod.yaml` for AWS, enabled optional Ingress, and kept sensitive values out of Git.
5. **CI/CD (GitHub Actions)**: built and pushed the Docker image to ECR on each `push` to `test-coding`, and prepared a deploy workflow for when EKS exists again.
6. **Observability (Prepared)**: values files and install steps exist in `helm/observability/README.md`.

## CI/CD

### 1) Build & Push to ECR (Automatic)

Workflow: `.github/workflows/build-push-ecr.yml`

- Trigger: `push` to branch `test-coding`
- Auth: GitHub OIDC -> AWS role (no long-lived keys)
- Tags pushed: `latest` and `${{ github.sha }}`

Required GitHub Secrets:

- `AWS_ROLE_ARN`: IAM role assumed by GitHub Actions (ECR push permissions).

### 2) Deploy to EKS (Manual, When Cluster Exists)

Workflow: `.github/workflows/deploy-eks.yml` (triggered via `workflow_dispatch`)

Inputs:

- `image_tag` (default: `latest`)
- `cluster_name` (default: `mm-devops-prod`)
- `namespace` (default: `mattermost`)
- `release_name` (default: `mattermost`)

Required GitHub Secrets:

- `AWS_ROLE_ARN`
- `MM_DB_PASSWORD` (injected at deploy time; not stored in `values.prod.yaml`)

## Deploying From Your Laptop (Alternative to CI Deploy)

When EKS is up and `kubectl` works:

```bash
cd infra
terraform output -raw cluster_name

aws eks update-kubeconfig --region eu-north-1 --name mm-devops-prod

helm upgrade --install mattermost ./helm/mattermost \
  -n mattermost \
  --create-namespace \
  -f ./helm/mattermost/values.prod.yaml \
  --set-string postgres.password="$MM_DB_PASSWORD"
```

## Ingress: What’s Real vs Optional

- The Helm chart supports ALB Ingress (`helm/mattermost/values.prod.yaml` has `ingress.enabled: true`).
- To actually get an ALB, you must install AWS Load Balancer Controller (see `docs/ingress-controller.md`).
- Simpler setup (no Ingress controller): set `ingress.enabled: false` and use `mattermost.service.type: LoadBalancer`.

## Challenges We Hit (And How We Fixed Them)

- **Postgres CrashLoopBackOff (`lost+found` / `initdb` not empty)**: avoid using the mount root as `PGDATA`; use a subdirectory under the mount.
- **Mattermost DSN parse error (`invalid URL escape`)**: URL-encode DB passwords when using DSN strings (or avoid special chars).
- **RDS SSL enforced (`no encryption`)**: use `sslmode=require` when connecting to RDS configured to require TLS.
- **S3 backend endpoint error (`Endpoint:  does not follow...`)**: don’t set S3 endpoint to an empty string; omit it or set a valid endpoint.
- **Helm stuck (`pending-upgrade`)**: use `helm rollback` to a known-good revision before retrying upgrades.
- **Helm namespace ownership conflict**: don’t manage an already-existing namespace from the chart, or label/annotate it for Helm ownership.
- **Pod Pending (`Insufficient memory`)**: on very small nodes, running 2 replicas + strict requests can block scheduling; start with 1 replica and right-size resources.
- **Terraform destroy dependency violations**: delete Kubernetes LoadBalancers/ENIs and empty ECR/S3 (or enable force-destroy) before tearing down VPC.
- **GitHub push rejected (100MB provider binary)**: never commit `.terraform/`; enforce `.gitignore` and remove cached files from Git index.

## Cost Control (Create/Destroy)

Create:

```bash
cd infra
terraform init
terraform apply -var-file=envs/prod.tfvars
```

Destroy:

```bash
cd infra
terraform destroy -var-file=envs/prod.tfvars -auto-approve -var s3_force_destroy=true
```

## Next Improvements (If You Continue)

1. Add DNS + TLS: `external-dns` + `cert-manager` (+ ACM if using ALB).
2. Add VPC Endpoints for ECR/S3 to reduce NAT cost and improve reliability.
3. Add metrics-server so HPA works reliably.
4. Tighten IAM policies for least privilege (GitHub role and IRSA roles).
5. Add smoke tests to CI (build validation, Helm lint, basic container scan).
