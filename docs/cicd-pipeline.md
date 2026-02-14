# CI/CD Pipeline (GitHub Actions)

```mermaid
flowchart LR
  dev[Developer]
  push[git push to test-coding]
  build[Workflow: build-push-ecr]
  oidc[OIDC assume-role\nAWS_ROLE_ARN]
  ecr[(ECR: mm-devops-prod)]
  deploy[Workflow: deploy-eks\n(manual or auto later)]
  eks[EKS rollout via Helm]

  dev --> push --> build
  build --> oidc --> ecr
  deploy --> oidc
  ecr --> eks
  deploy --> eks
```

## What To Screenshot

- GitHub Actions run page:
  - `build-push-ecr` successful run (steps + green check).
  - `deploy-eks` run (when EKS exists).
