variable "HARNESS_API_KEY" {
 type        = string
 }

variable "HARNESS_ACCOUNT_ID" {
 type        = string
 }

variable "HARNESS_PROJECT_ID" {
 type        = string
 }

variable "HARNESS_ORG_ID" {
 type        = string
 }
variable "HARNESS_GITHUB_SECRET_VALUE" {
  description = "The secret value for GitHub access"
  type        = string
  sensitive   = true
}

variable "AWS_SECRET_KEY" {
  description = "The secret key for AWS"
  type        = string
  sensitive   = true
}

variable "HARNESS_AWS_CONNECTOR_ID" {
  description = "The identifier for the Harness AWS connector"
  type        = string
}

variable "AWS_ACCESS_KEY" {
  description = "The access key for AWS"
  type        = string
  sensitive   = true
}

variable "HARNESS_GITHUB_CONNECTOR_ID" {
  description = "The identifier for the Harness GitHub connector"
  type        = string
}

variable "HARNESS_GITHUB_URL" {
  description = "The URL for GitHub"
  type        = string
}

variable "GITHUB_USER" {
  description = "The GitHub username"
  type        = string
}
