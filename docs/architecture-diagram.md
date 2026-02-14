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

flowchart LR
  %% External
  user[User Browser]
  gha[GitHub Actions]

  subgraph aws[AWS eu-north-1]
    direction LR

    ekscp[EKS API]

    subgraph vpc[VPC]
      direction LR

      subgraph pub[Public Subnets]
        direction TB
        alb[ALB]
        nat[NAT]
        igw[IGW]
      end

      subgraph privApp[Private Subnets app]
        direction TB
        ing[Ingress]
        lbc[ALB Controller]
        svc[Service ClusterIP]
        mm[Mattermost Pods]
        ng[Node Group]
        efsmt[EFS Mount Targets]
      end

      subgraph privData[Private Subnets data]
        direction TB
        rds[(RDS)]
        cache[(ElastiCache Redis)]
      end
    end

    awsapi[AWS Public APIs]

    subgraph services[AWS Services]
      direction TB
      ecr[(ECR)]
      s3[(S3)]
      efs[(EFS)]
    end
  end

  %% Traffic
  user --> alb --> svc --> mm

  %% Ingress provisions ALB (conceptual)
  ing -.-> lbc
  lbc -.-> alb

  %% CI/CD
  gha --> ecr
  gha --> ekscp

  %% Scheduling
  ekscp --> ng --> mm

  %% App dependencies
  mm --> rds
  mm --> cache
  mm --> s3
  mm --> efsmt --> efs

  %% Outbound to AWS APIs (no VPC endpoints)
  ng --> nat --> igw --> awsapi
  awsapi --> ecr
  awsapi --> s3

  %% Styling
  classDef awsfill fill:#FF9900,stroke:#B85E00,color:#232F3E;
  classDef dark fill:#232F3E,stroke:#111820,color:#FFFFFF;
  classDef light fill:#F2F3F3,stroke:#D5DBDB,color:#232F3E;
  classDef data fill:#E6F2FF,stroke:#3B8EEA,color:#0B1F2A;

  class aws,vpc,pub,privApp,privData,services light;
  class igw,nat dark;
  class gha awsfill;
  class user light;
  class ekscp,awsapi light;
  class alb,ng,lbc,ing,svc,mm light;
  class rds,cache,ecr,s3,efs,efsmt data;

  linkStyle default stroke:#545B64,stroke-width:1.2px
```

## Notes

- Traffic is exposed via Ingress (ALB -> Service ClusterIP -> Pods).
- App data path: `Mattermost -> RDS / ElastiCache / S3 / EFS`.
- CI/CD path: `GitHub Actions -> ECR -> EKS rollout`.
