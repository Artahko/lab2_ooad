variable "project_id" {
  description = "Google Cloud project ID (permanent, globally unique), e.g. spry-artem-2026"
  type        = string
}

variable "region" {
  description = "Region for Cloud Run, Cloud SQL and Artifact Registry"
  type        = string
  default     = "us-central1"
}

variable "project_name" {
  description = "Prefix for resource names and the value of the project_name label"
  type        = string
  default     = "spry"
}

variable "image_tag" {
  description = "Tag of the backend image in Artifact Registry (pushed before terraform apply)"
  type        = string
  default     = "latest"
}

variable "db_tier" {
  description = "Cloud SQL machine type: db-f1-micro (shared core, 0.6 GB) is the smallest"
  type        = string
  default     = "db-f1-micro"
}

variable "db_activation_policy" {
  description = "ALWAYS = running (billed per hour), NEVER = stopped (only storage is billed)"
  type        = string
  default     = "ALWAYS"
}

variable "cors_origins" {
  description = "Origins allowed to call the API, comma-separated (the Firebase Hosting URL)"
  type        = string
  default     = ""
}

# Sign-in stays on AWS for now: the API keeps verifying Cognito ID tokens.
variable "cognito_user_pool_id" {
  description = "Cognito user pool whose ID tokens the API accepts (public ID, not a secret)"
  type        = string
  default     = ""
}

variable "cognito_client_id" {
  description = "Cognito app client ID (public ID, not a secret)"
  type        = string
  default     = ""
}
