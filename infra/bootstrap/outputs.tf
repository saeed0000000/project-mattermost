output "tfstate_bucket" {
  value = aws_s3_bucket.tfstate.bucket
}

output "tf_lock_table" {
  value = aws_dynamodb_table.tf_lock.name
}
