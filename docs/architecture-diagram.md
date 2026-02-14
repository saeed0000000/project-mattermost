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

  subgraph aws[AWS eu-north-1]
    subgraph vpc[VPC]
      igw[Internet Gateway]

      subgraph pub[Public Subnets]
        nat[NAT Gateway]
      end

      subgraph privApp[Private Subnets app]
        eksapi[EKS API endpoint public]
        eks[EKS Cluster]
        ng[Managed Node Group]
        lbc[AWS Load Balancer Controller]
        ing[Ingress ALB]
        svc[Service ClusterIP]
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

  %% User traffic path
  user --> ing --> svc --> mm

  %% App dependencies
  mm --> rds
  mm --> cache
  mm --> s3
  mm --> efs

  %% Control plane and scheduling
  eksapi --> eks --> ng --> mm

  %% CI/CD path
  gha --> ecr
  ecr --> mm
  gha --> eksapi

  %% Outbound to AWS services (no VPC endpoints)
  ng --> nat --> igw

  %% Styling
  classDef awsfill fill:#FF9900,stroke:#B85E00,color:#232F3E;
  classDef dark fill:#232F3E,stroke:#111820,color:#FFFFFF;
  classDef light fill:#F2F3F3,stroke:#D5DBDB,color:#232F3E;
  classDef data fill:#E6F2FF,stroke:#3B8EEA,color:#0B1F2A;

  class aws,vpc,pub,privApp,privData light;
  class igw,nat dark;
  class gha,ecr awsfill;
  class eksapi,eks,ng,lbc,ing,svc,mm light;
  class rds,cache,s3,efs data;
```

## Notes

- Traffic is exposed via Ingress (AWS Load Balancer Controller -> ALB -> Service ClusterIP).
- App data path: `Mattermost -> RDS / ElastiCache / S3 / EFS`.
- CI/CD path: `GitHub Actions -> ECR -> EKS rollout`.
