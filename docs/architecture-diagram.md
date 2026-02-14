# Mattermost DevOps Architecture

```mermaid
%%{init: {'theme':'base','themeVariables':{
  'fontFamily':'Segoe UI, Arial, sans-serif',
  'primaryColor':'#FF9900',
  'primaryTextColor':'#232F3E',
  'primaryBorderColor':'#B85E00',
  'lineColor':'#545B64',
  'tertiaryColor':'#F2F3F3'
}}}%%

flowchart TB
  user[User Browser]
  gha[GitHub Actions CI/CD]
  ecr[(Amazon ECR)]
  s3[(Amazon S3 File Storage)]
  efs[(Amazon EFS)]

  subgraph aws[AWS eu-north-1]
    %% EKS control plane is managed by AWS (not inside your subnets)
    ekscp[EKS Control Plane Public API]

    subgraph vpc[VPC]
      igw[Internet Gateway]

      subgraph pub[Public Subnets]
        alb[ALB Ingress]
        nat[NAT Gateway]
      end

      subgraph privApp[Private Subnets app]
        ng[Managed Node Group EC2 Workers]
        lbc[AWS Load Balancer Controller]
        ing[Kubernetes Ingress Resource]
        svc[Service ClusterIP]
        mm[Mattermost Pods]
        efsmt[EFS Mount Targets]
      end

      subgraph privData[Private Subnets data]
        rds[(RDS PostgreSQL)]
        cache[(ElastiCache Redis)]
      end
    end
  end

  %% User traffic path
  user --> alb --> svc --> mm

  %% Ingress provisions ALB via the controller (conceptual)
  ing -. rules .-> lbc
  lbc -. provisions/updates .-> alb

  %% Control plane schedules workloads onto nodes
  ekscp --> ng --> mm

  %% App dependencies
  mm --> rds
  mm --> cache
  mm --> s3
  mm --> efs
  efs --> efsmt --> mm

  %% CI/CD
  gha --> ecr
  gha --> ekscp

  %% Image pulls / outbound to AWS services (no VPC endpoints)
  ng --> nat --> igw
  nat --> ecr
  nat --> s3

  %% Styling
  classDef awsfill fill:#FF9900,stroke:#B85E00,color:#232F3E;
  classDef dark fill:#232F3E,stroke:#111820,color:#FFFFFF;
  classDef light fill:#F2F3F3,stroke:#D5DBDB,color:#232F3E;
  classDef data fill:#E6F2FF,stroke:#3B8EEA,color:#0B1F2A;

  class vpc,pub,privApp,privData light;
  class igw,nat dark;
  class gha awsfill;
  class ekscp light;
  class alb,ng,lbc,ing,svc,mm light;
  class rds,cache,ecr,s3,efs,efsmt data;
```

## Notes

- Traffic is exposed via Ingress (ALB -> Service ClusterIP -> Pods).
- App data path: `Mattermost -> RDS / ElastiCache / S3 / EFS`.
- CI/CD path: `GitHub Actions -> ECR -> EKS rollout`.
