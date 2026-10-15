output "public_url" {
  description = "URL policy-bot advertises. Use it for the GitHub App's homepage, webhook, and callback URLs."
  value       = local.public_url
}

output "webhook_url" {
  value = "${local.public_url}/api/github/hook"
}

output "oauth_callback_url" {
  value = "${local.public_url}/api/github/auth"
}

output "run_app_url" {
  description = "Direct Cloud Run URL. Returns 404 when the load balancer is in front."
  value       = local.run_app_url
}

output "load_balancer_ip" {
  value = local.use_lb ? google_compute_global_address.lb[0].address : null
}

output "image" {
  value = local.image
}

output "service_account" {
  value = google_service_account.policy_bot.email
}

output "secret_ids" {
  description = "Secret Manager secret IDs that need a version before deploy_service=true."
  value       = { for k, s in google_secret_manager_secret.runtime : k => s.secret_id }
}
