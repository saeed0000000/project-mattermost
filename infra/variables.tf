variable "region" {
  type        = string
  description = "AWS region"
  default     = "eu-north-1"
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI profile to use for authentication"
  default     = "my-terraform-profile"
}

variable "project_name" {
  type        = string
  description = "Base name for resources"
  default     = "mm-devops"
}

variable "environment" {
  type        = string
  description = "Environment name (dev or prod)"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}

variable "az_count" {
  type        = number
  description = "Number of availability zones to use"
  default     = 2
}

variable "nat_single" {
  type        = bool
  description = "Use a single NAT gateway for all private subnets"
  default     = true
}

variable "cluster_version" {
  type        = string
  description = "EKS Kubernetes version"
  default     = "1.29"
}

variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for node group"
  default     = "t3.micro"
}

variable "node_min_size" {
  type        = number
  description = "Minimum size of node group"
  default     = 3
}

variable "node_max_size" {
  type        = number
  description = "Maximum size of node group"
  default     = 6
}

variable "node_desired_size" {
  type        = number
  description = "Desired size of node group"
  default     = 3
}

variable "rds_instance_class" {
  type        = string
  description = "RDS instance class"
  default     = "db.t3.small"
}

variable "rds_allocated_storage" {
  type        = number
  description = "RDS allocated storage (GiB)"
  default     = 20
}

variable "rds_engine_version" {
  type        = string
  description = "PostgreSQL engine version"
  default     = null
}

variable "rds_db_name" {
  type        = string
  description = "Database name"
  default     = "mattermost"
}

variable "rds_username" {
  type        = string
  description = "Database username"
  default     = "mmuser"
}

variable "rds_multi_az" {
  type        = bool
  description = "Enable Multi-AZ for RDS"
  default     = true
}

variable "rds_backup_retention_period" {
  type        = number
  description = "RDS backup retention period in days (0 disables backups)"
  default     = 0
}

variable "redis_node_type" {
  type        = string
  description = "ElastiCache node type"
  default     = "cache.t3.small"
}

variable "redis_engine_version" {
  type        = string
  description = "Redis engine version"
  default     = "7.1"
}

variable "redis_num_cache_clusters" {
  type        = number
  description = "Number of Redis nodes in replication group"
  default     = 2
}

variable "s3_force_destroy" {
  type        = bool
  description = "Allow destroying the S3 bucket with objects"
  default     = false
}
