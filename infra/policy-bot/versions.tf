terraform {
  required_version = ">= 1.5.7"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }

  # Separate state from the xyla-development-2 Django environment. Other
  # people's applies of that root cannot touch resources in this state.
  # For a purely local experiment, delete this block and run `terraform init`
  # again (state lands in ./terraform.tfstate, which is git-ignored).
  backend "gcs" {
    bucket = "xyla-development-2-bucket-tfstate"
    prefix = "terraform/policy-bot-prototype"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
