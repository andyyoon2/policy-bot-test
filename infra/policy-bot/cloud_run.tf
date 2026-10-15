resource "google_cloud_run_v2_service" "policy_bot" {
  count = var.deploy_service ? 1 : 0

  name                = var.service_name
  location            = var.region
  deletion_protection = false

  # Behind the load balancer only the custom hostname answers; the run.app
  # URL returns 404. Without a hostname the service is reachable directly.
  ingress = local.use_lb ? "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" : "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.policy_bot.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = 2
    }

    containers {
      image = local.image
      args  = ["server", "--config", "/secrets/policy-bot.yml"]

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
      }

      env {
        name  = "POLICYBOT_PUBLIC_URL"
        value = local.public_url
      }
      env {
        name  = "POLICYBOT_LOG_LEVEL"
        value = "info"
      }
      env {
        name  = "GITHUB_APP_INTEGRATION_ID"
        value = var.github_app_id
      }
      env {
        name  = "GITHUB_OAUTH_CLIENT_ID"
        value = var.github_oauth_client_id
      }

      dynamic "env" {
        for_each = local.runtime_secrets
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.runtime[env.key].secret_id
              version = "latest"
            }
          }
        }
      }

      volume_mounts {
        name       = "config"
        mount_path = "/secrets"
      }
    }

    volumes {
      name = "config"
      secret {
        secret = google_secret_manager_secret.config.secret_id
        items {
          version = "latest"
          path    = "policy-bot.yml"
        }
      }
    }
  }

  depends_on = [
    google_secret_manager_secret_iam_member.runtime,
    google_secret_manager_secret_iam_member.config,
    google_secret_manager_secret_version.config,
  ]
}

# GitHub webhooks and the browser UI arrive unauthenticated.
resource "google_cloud_run_v2_service_iam_member" "public" {
  count = var.deploy_service ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.policy_bot[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
