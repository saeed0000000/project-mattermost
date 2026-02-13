variable "region" {
  type        = string
  description = "AWS region"
  default     = "eu-north-1"
}

variable "project_name" {
  type        = string
  description = "Base name for resources"
  default     = "mm-devops"
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI profile to use for authentication"
  default     = "my-terraform-profile"
}
