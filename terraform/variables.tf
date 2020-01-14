#
# Variables configuration
#

variable "project_name" {
  type        = string
  description = "A project name which will be used for naming all resources of the infra setup"
}

variable "database_name" {
  type        = string
  description = "A database name which will be used for AWS RDS database naming"
}

variable "database_username" {
  type        = string
  description = "Database username which will be used for AWS RDS Authentication credentials"
}

variable "database_password" {
  type        = string
  description = "Database password which will be used for AWS RDS Authentication credentials"
}

variable "project_env" {
  default     = "production"
  type        = string
  description = "The deployment environment you wish to call this project eg.: production"
}

variable "codebuild_github_repo" {
  type        = string
  description = "Github repository url Cloudbuild uses to build the image."
}

variable "github_personal_access_token" {
  type        = string
  description = "Github personal token for the account which the github repo belongs to."
}

variable "dockerfile_path" {
  type        = string
  description = "Path for Dockerfile in the github repo"
}

variable "aws_region" {
  type        = string
  description = "The AWS Region where you wish to have all the resources created, eg: us-west-2"
}

variable "AWS_ACCESS_KEY_ID" {
  type = string
  description = "AWS ACCESS ID"
}

variable "AWS_SECRET_ACCESS_KEY" {
  type = string
  description = "AWS SECRET KEY"
}

variable "cluster_admins_arns" {
  type = list
  default = []
  description = "List of ARNs to be added for cluster access"
}
