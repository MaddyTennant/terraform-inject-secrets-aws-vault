variable "project_name" {
  type        = string
  description = "Name of this project."

  default     = "dynamic-aws-creds-vault"
}

variable "region" {
  type        = string
  description = "AWS region for all resources."

  default = "ap-southeast-2"
}