terraform {
  required_version = ">= 1.10"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Its own state, separate from infra/ (AWS): one plan must not be able to break both clouds.
  # With HCP Terraform, uncomment and create a second workspace, e.g. spry-gcp:
  #
  # cloud {
  #   organization = "<your-hcp-organization>"
  #   workspaces {
  #     name = "spry-gcp"
  #   }
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = {
    project_name = var.project_name
    managed_by   = "terraform"
  }
}
