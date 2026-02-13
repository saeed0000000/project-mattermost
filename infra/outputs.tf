output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value     = module.eks.cluster_certificate_authority_data
  sensitive = true
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "ecr_repository_url" {
  value = aws_ecr_repository.mattermost.repository_url
}

output "rds_endpoint" {
  value = aws_db_instance.rds.address
}

output "rds_username" {
  value = var.rds_username
}

output "rds_password" {
  value     = random_password.rds.result
  sensitive = true
}

output "redis_primary_endpoint" {
  value = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_port" {
  value = aws_elasticache_replication_group.redis.port
}

output "s3_bucket" {
  value = aws_s3_bucket.mm_files.bucket
}

output "mattermost_service_account_role_arn" {
  value = aws_iam_role.mm_s3.arn
}

output "efs_file_system_id" {
  value = aws_efs_file_system.mm.id
}
