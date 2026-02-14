# Mattermost DevOps Architecture

```mermaid
%%{init: {'theme':'base','themeVariables':{
  'fontFamily':'Segoe UI, Arial, sans-serif',
  'primaryColor':'#FF9900',
  'primaryTextColor':'#232F3E',
  'primaryBorderColor':'#B85E00',
  'lineColor':'#545B64',
  'tertiaryColor':'#F2F3F3'
},'flowchart':{'curve':'stepAfter'}}}%%

flowchart TB
  %% External actors
  subgraph ext[External]
    direction LR
    user[User Browser]
    gha[GitHub Actions]
    internet[Internet]
  end

  subgraph aws[AWS eu-north-1]
    direction TB
    ekscp[EKS Control Plane API]

    subgraph services[AWS Managed Services]
      direction LR
      ecr[(ECR)]
      s3[(S3)]
      efs[(EFS)]
    end

    subgraph vpc[VPC]
      direction TB
      igw[Internet Gateway]

      subgraph pub[Public Subnets]
        nat[NAT Gateway]
        alb[ALB]
      end

      subgraph privApp[Private Subnets app]
        ng[Node Group]
        lbc[ALB Controller]
        ing[Ingress Resource]
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

  %% Traffic path
  user --> alb --> svc --> mm

  %% Ingress provisions ALB via the controller (conceptual)
  ing -. rules .-> lbc
  lbc -. provisions .-> alb

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
  igw --> internet
  internet --> ecr
  internet --> s3

  %% Styling
  classDef awsfill fill:#FF9900,stroke:#B85E00,color:#232F3E;
  classDef dark fill:#232F3E,stroke:#111820,color:#FFFFFF;
  classDef light fill:#F2F3F3,stroke:#D5DBDB,color:#232F3E;
  classDef data fill:#E6F2FF,stroke:#3B8EEA,color:#0B1F2A;

  class ext,aws,vpc,pub,privApp,privData,services light;
  class igw,nat dark;
  class gha awsfill;
  class user light;
  class internet light;
  class ekscp light;
  class alb,ng,lbc,ing,svc,mm light;
  class rds,cache,ecr,s3,efs,efsmt data;
```

## Notes

- Traffic is exposed via Ingress (ALB -> Service ClusterIP -> Pods).
- App data path: `Mattermost -> RDS / ElastiCache / S3 / EFS`.
- CI/CD path: `GitHub Actions -> ECR -> EKS rollout`.
