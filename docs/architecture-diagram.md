# Mattermost DevOps Architecture

```mermaid
flowchart TB
  user[User Browser]
  gha[GitHub Actions CI/CD]
  ecr[(Amazon ECR)]

  subgraph aws[AWS eu-north-1]
    subgraph vpc[VPC]
      igw[Internet Gateway]
      subgraph pub[Public Subnets]
        lb[AWS Load Balancer]
        nat[NAT Gateway]
      end
      subgraph privApp[Private Subnets app]
        eks[EKS Cluster]
        ng[Managed Node Group]
        svc[K8s Service LoadBalancer]
        mm[Mattermost Pods]
      end
    end
    subgraph privData[Private Subnets data]
      rds[(RDS PostgreSQL)]
      cache[(ElastiCache Redis)]
    end
    s3[(S3 File Storage)]
    efs[(EFS Shared Storage)]
  end

  user --> lb --> svc --> mm
  mm --> s3
  mm --> efs
  mm --> rds
  mm --> cache

  gha --> ecr --> mm
  eks --> ng --> mm
  ng --> nat --> igw
```

## Notes

- Traffic is exposed via `Service type=LoadBalancer` (no Ingress controller).
- App data path: `Mattermost -> RDS / ElastiCache / S3 / EFS`.
- CI/CD path: `GitHub Actions -> ECR -> EKS rollout`.
