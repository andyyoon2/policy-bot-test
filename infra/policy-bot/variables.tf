variable "project_id" {
  description = "GCP project that hosts the prototype."
  type        = string
  default     = "xyla-development-2"
}

variable "region" {
  description = "Region for Cloud Run and Artifact Registry."
  type        = string
  default     = "us-central1"
}

variable "service_name" {
  description = "Name for the Cloud Run service and the prefix for every resource this root creates."
  type        = string
  default     = "policy-bot-proto"
}

variable "policy_bot_version" {
  description = "policy-bot image tag from Docker Hub (palantirtechnologies/policy-bot)."
  type        = string
  default     = "1.41.2"
}

variable "github_app_id" {
  description = "App ID of the policy-bot GitHub App. Known only after the App is created, so empty on the first apply."
  type        = string
  default     = ""
}

variable "github_oauth_client_id" {
  description = "OAuth client ID of the policy-bot GitHub App (for its web UI login)."
  type        = string
  default     = ""
}

variable "deploy_service" {
  description = "Create the Cloud Run service, load balancer, and DNS record. Keep false until the GitHub App exists and every secret has a version."
  type        = bool
  default     = false
}

variable "min_instances" {
  description = "Cloud Run minimum instances. 0 is fine for the prototype; use 1 when the status is required."
  type        = number
  default     = 0
}

variable "status_check_context" {
  description = "Prefix of the commit status policy-bot posts. The full context is '<prefix>: <base branch>'."
  type        = string
  default     = "policy-bot"
}

variable "hostname" {
  description = "Public hostname served by the load balancer. Empty string serves only the run.app URL and skips LB and DNS."
  type        = string
  default     = "policy-bot.xyladev2.live"
}

variable "dns_zone_name" {
  description = "Name of the existing public Cloud DNS managed zone that holds `hostname`."
  type        = string
  default     = "xyladev2-live"
}
