# External HTTPS load balancer in front of Cloud Run plus a DNS A record.
# Mirrors infra/xyla_django/modules/cloud-run-load-balancer in the xyla repo.
# The Google-managed certificate can take 30 to 60 minutes to become ACTIVE;
# the hostname serves TLS errors until then.

resource "google_compute_global_address" "lb" {
  count = local.use_lb ? 1 : 0

  name         = "${var.service_name}-lb-ip"
  address_type = "EXTERNAL"

  depends_on = [google_project_service.apis]
}

resource "google_compute_ssl_policy" "lb" {
  count = local.use_lb ? 1 : 0

  name            = "${var.service_name}-ssl-policy"
  profile         = "RESTRICTED"
  min_tls_version = "TLS_1_2"

  depends_on = [google_project_service.apis]
}

resource "google_compute_managed_ssl_certificate" "lb" {
  count = local.use_lb ? 1 : 0

  name = "${var.service_name}-cert"

  managed {
    domains = [var.hostname]
  }

  depends_on = [google_project_service.apis]
}

resource "google_compute_region_network_endpoint_group" "lb" {
  count = local.use_lb ? 1 : 0

  name                  = "${var.service_name}-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.policy_bot[0].name
  }
}

resource "google_compute_backend_service" "lb" {
  count = local.use_lb ? 1 : 0

  name                  = "${var.service_name}-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  enable_cdn            = false

  connection_draining_timeout_sec = 10

  backend {
    group           = google_compute_region_network_endpoint_group.lb[0].id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  log_config {
    enable = true
  }
}

resource "google_compute_url_map" "lb" {
  count = local.use_lb ? 1 : 0

  name            = "${var.service_name}-url-map"
  default_service = google_compute_backend_service.lb[0].id
}

resource "google_compute_target_https_proxy" "lb" {
  count = local.use_lb ? 1 : 0

  name             = "${var.service_name}-https-proxy"
  url_map          = google_compute_url_map.lb[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.lb[0].id]
  ssl_policy       = google_compute_ssl_policy.lb[0].id
}

resource "google_compute_global_forwarding_rule" "lb" {
  count = local.use_lb ? 1 : 0

  name                  = "${var.service_name}-fr"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.lb[0].id
  ip_address            = google_compute_global_address.lb[0].id
}

resource "google_dns_record_set" "lb" {
  count = local.use_lb ? 1 : 0

  name         = "${var.hostname}."
  managed_zone = var.dns_zone_name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.lb[0].address]
}
