data "google_project" "this" {
  project_id = var.project_id
}

locals {
  apis = toset([
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
  ])

  use_lb = var.deploy_service && var.hostname != ""

  image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.dockerhub.repository_id}/palantirtechnologies/policy-bot:${var.policy_bot_version}"

  # Cloud Run v2 URLs are deterministic, so the webhook URL is known before
  # the service exists.
  run_app_url = "https://${var.service_name}-${data.google_project.this.number}.${var.region}.run.app"
  public_url  = var.hostname != "" ? "https://${var.hostname}" : local.run_app_url

  # Secret Manager secret per runtime secret, keyed by the env var policy-bot
  # reads it from. Versions are added out of band (scripts/set-secrets.sh).
  runtime_secrets = {
    GITHUB_APP_PRIVATE_KEY     = "github-app-private-key"
    GITHUB_APP_WEBHOOK_SECRET  = "github-app-webhook-secret"
    GITHUB_OAUTH_CLIENT_SECRET = "github-oauth-client-secret"
    POLICYBOT_SESSIONS_KEY     = "sessions-key"
  }
}

resource "google_project_service" "apis" {
  for_each = local.apis

  service            = each.value
  disable_on_destroy = false
}

# Pull-through cache for Docker Hub so Cloud Run can run the upstream image
# without a manual copy into Artifact Registry.
resource "google_artifact_registry_repository" "dockerhub" {
  location      = var.region
  repository_id = "${var.service_name}-dockerhub"
  description   = "Remote repository proxying Docker Hub for ${var.service_name}"
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"

  remote_repository_config {
    description = "Docker Hub"
    docker_repository {
      public_repository = "DOCKER_HUB"
    }
  }

  depends_on = [google_project_service.apis]
}

resource "google_service_account" "policy_bot" {
  account_id   = var.service_name
  display_name = "policy-bot prototype runtime"
}

resource "google_secret_manager_secret" "runtime" {
  for_each = local.runtime_secrets

  secret_id = "${var.service_name}-${each.value}"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_iam_member" "runtime" {
  for_each = google_secret_manager_secret.runtime

  secret_id = each.value.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.policy_bot.email}"
}

# Non-secret config file, mounted at /secrets/policy-bot.yml. Secrets arrive
# through environment variables, which policy-bot layers over the file.
resource "google_secret_manager_secret" "config" {
  secret_id = "${var.service_name}-config"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "config" {
  secret = google_secret_manager_secret.config.id
  secret_data = templatefile("${path.module}/policy-bot.yml.tftpl", {
    public_url           = local.public_url
    status_check_context = var.status_check_context
  })
}

resource "google_secret_manager_secret_iam_member" "config" {
  secret_id = google_secret_manager_secret.config.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.policy_bot.email}"
}
