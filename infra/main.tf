

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  cluster_name   = "${var.project_name}-${var.environment}"
  azs            = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  public_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 10)]
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.cluster_name
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  enable_nat_gateway = true
  single_nat_gateway = var.nat_single
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = local.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true
  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns   = {}
    kube-proxy = {}
    vpc-cni   = {}
    eks-pod-identity-agent = {}
    aws-ebs-csi-driver = {
      service_account_role_arn = aws_iam_role.ebs_csi.arn
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
      timeouts = {
        create = "40m"
        update = "40m"
        delete = "20m"
      }
    }
    aws-efs-csi-driver = {
      service_account_role_arn = aws_iam_role.efs_csi.arn
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
      timeouts = {
        create = "40m"
        update = "40m"
        delete = "20m"
      }
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = [var.node_instance_type]
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      subnet_ids = module.vpc.private_subnets
    }
  }

  tags = local.tags
}

data "aws_iam_policy" "ebs_csi" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

data "aws_iam_policy_document" "ebs_csi_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${local.cluster_name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = data.aws_iam_policy.ebs_csi.arn
}

data "aws_iam_policy" "efs_csi" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

data "aws_iam_policy_document" "efs_csi_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:efs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "efs_csi" {
  name               = "${local.cluster_name}-efs-csi"
  assume_role_policy = data.aws_iam_policy_document.efs_csi_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "efs_csi" {
  role       = aws_iam_role.efs_csi.name
  policy_arn = data.aws_iam_policy.efs_csi.arn
}

resource "aws_security_group" "rds" {
  name        = "${local.cluster_name}-rds"
  description = "Allow PostgreSQL from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_db_subnet_group" "rds" {
  name       = "${local.cluster_name}-rds"
  subnet_ids = module.vpc.private_subnets
  tags       = local.tags
}

resource "random_password" "rds" {
  length           = 20
  special          = true
  override_special = "_%@!"
}

resource "aws_db_instance" "rds" {
  identifier              = "${local.cluster_name}-postgres"
  engine                  = "postgres"
  engine_version          = var.rds_engine_version
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  db_name                 = var.rds_db_name
  username                = var.rds_username
  password                = random_password.rds.result
  port                    = 5432
  multi_az                = var.rds_multi_az
  publicly_accessible     = false
  db_subnet_group_name    = aws_db_subnet_group.rds.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  storage_encrypted       = true
  backup_retention_period = var.rds_backup_retention_period
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true
  tags                    = local.tags
}

resource "aws_security_group" "redis" {
  name        = "${local.cluster_name}-redis"
  description = "Allow Redis from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.cluster_name}-redis"
  subnet_ids = module.vpc.private_subnets
  tags       = local.tags
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id          = "${local.cluster_name}-redis"
  description                   = "Redis for Mattermost"
  engine                        = "redis"
  engine_version                = var.redis_engine_version
  node_type                     = var.redis_node_type
  port                          = 6379
  subnet_group_name             = aws_elasticache_subnet_group.redis.name
  security_group_ids            = [aws_security_group.redis.id]
  automatic_failover_enabled    = true
  multi_az_enabled              = true
  num_cache_clusters            = var.redis_num_cache_clusters
  parameter_group_name          = "default.redis7"
  at_rest_encryption_enabled    = true
  transit_encryption_enabled    = false
  apply_immediately             = true
  tags                          = local.tags
}

resource "random_id" "s3_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "mm_files" {
  bucket        = lower("${local.cluster_name}-files-${random_id.s3_suffix.hex}")
  force_destroy = var.s3_force_destroy
  tags          = local.tags
}

resource "aws_s3_bucket_versioning" "mm_files" {
  bucket = aws_s3_bucket.mm_files.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mm_files" {
  bucket = aws_s3_bucket.mm_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "mm_files" {
  bucket = aws_s3_bucket.mm_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "mm_s3" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads"
    ]
    resources = [aws_s3_bucket.mm_files.arn]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]
    resources = ["${aws_s3_bucket.mm_files.arn}/*"]
  }
}

data "aws_iam_policy_document" "mm_s3_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:sub"
      values   = ["system:serviceaccount:mattermost:mattermost"]
    }
  }
}

resource "aws_iam_role" "mm_s3" {
  name               = "${local.cluster_name}-mattermost-s3"
  assume_role_policy = data.aws_iam_policy_document.mm_s3_assume.json
  tags               = local.tags
}

resource "aws_iam_policy" "mm_s3" {
  name   = "${local.cluster_name}-mattermost-s3"
  policy = data.aws_iam_policy_document.mm_s3.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "mm_s3" {
  role       = aws_iam_role.mm_s3.name
  policy_arn = aws_iam_policy.mm_s3.arn
}

resource "aws_security_group" "efs" {
  name        = "${local.cluster_name}-efs"
  description = "Allow NFS from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_efs_file_system" "mm" {
  creation_token = "${local.cluster_name}-efs"
  encrypted      = true
  tags           = local.tags
}

resource "aws_efs_mount_target" "mm" {
  count = var.az_count

  file_system_id  = aws_efs_file_system.mm.id
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_ecr_repository" "mattermost" {
  name = "${var.project_name}-${var.environment}"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

resource "aws_ecr_lifecycle_policy" "mattermost" {
  repository = aws_ecr_repository.mattermost.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 50 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 50
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
