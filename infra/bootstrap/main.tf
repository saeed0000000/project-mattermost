provider "aws" {
  region = var.region
  profile = var.aws_profile
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  bucket_name = lower("${var.project_name}-tfstate-${random_id.suffix.hex}")
  table_name  = "${var.project_name}-tf-locks"
  tags = {
    Project = var.project_name
  }
}

resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  tags = local.tags
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tf_lock" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = local.tags
}
