variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "devops"
}

variable "project_name" {
  description = "Project name"
  type        = string
}

# Google OAuth Configuration
variable "google_client_id" {
  description = "Google OAuth Client ID"
  type        = string
  sensitive   = true
}

variable "google_client_secret" {
  description = "Google OAuth Client Secret"
  type        = string
  sensitive   = true
}

# Optional domain for custom callbacks
variable "domain_name" {
  description = "Custom domain name for callbacks (optional)"
  type        = string
  default     = ""
}