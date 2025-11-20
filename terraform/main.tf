module "caddy01" {
  source = "./modules/caddy"

  instance_name        = "caddy01"
  profile_name         = "caddy"
  cloudflare_api_token = var.cloudflare_api_token

  # Service blocks from all modules
  service_blocks = [
    module.grafana01.caddy_config_block,
    # Add more service blocks here as you create more modules
  ]

  # Network configuration - reference managed networks
  production_network = incus_network.production.name
  management_network = "incusbr0"

  # Ensure networks are created before the container
  depends_on = [
    incus_network.development,
    incus_network.testing,
    incus_network.production
  ]

  # Optional: Override defaults if needed
  # cpu_limit            = "2"
  # memory_limit         = "1GB"
  # storage_pool         = "default"
}

module "grafana01" {
  source = "./modules/grafana"

  instance_name = "grafana01"
  profile_name  = "grafana01"

  # Network configuration - use production network
  monitoring_network = incus_network.production.name

  # Domain configuration for reverse proxy
  domain           = "grafana.accuser.dev"
  allowed_ip_range = "192.168.68.0/22"
  grafana_port     = "3000"

  # Environment variables for Grafana configuration
  environment_variables = {
    GF_SECURITY_ADMIN_USER     = "admin"
    GF_SECURITY_ADMIN_PASSWORD = "changeme"
    GF_SERVER_HTTP_PORT        = "3000"
  }

  # Enable persistent storage for dashboards and data
  enable_data_persistence = true
  data_volume_name        = "grafana01-data"
  data_volume_size        = "10GB"

  # Resource limits
  cpu_limit    = "2"
  memory_limit = "1GB"

  # Ensure networks are created before the container
  depends_on = [
    incus_network.development,
    incus_network.testing,
    incus_network.production
  ]
}

module "loki01" {
  source = "./modules/loki"

  instance_name = "loki01"
  profile_name  = "loki01"

  # Network configuration - use production network (internal monitoring)
  monitoring_network = incus_network.production.name

  # Loki configuration
  loki_port = "3100"

  # Enable persistent storage for log data
  enable_data_persistence = true
  data_volume_name        = "loki01-data"
  data_volume_size        = "50GB"

  # Resource limits - Loki needs more memory for log processing
  cpu_limit    = "2"
  memory_limit = "2GB"

  # Ensure networks are created before the container
  depends_on = [
    incus_network.development,
    incus_network.testing,
    incus_network.production
  ]
}

module "prometheus01" {
  source = "./modules/prometheus"

  instance_name = "prometheus01"
  profile_name  = "prometheus01"

  # Network configuration - use production network (internal monitoring)
  monitoring_network = incus_network.production.name

  # Prometheus configuration
  prometheus_port = "9090"

  # Enable persistent storage for metrics data
  enable_data_persistence = true
  data_volume_name        = "prometheus01-data"
  data_volume_size        = "100GB"

  # Resource limits - Prometheus needs memory for time-series data
  cpu_limit    = "2"
  memory_limit = "2GB"

  # Ensure networks are created before the container
  depends_on = [
    incus_network.development,
    incus_network.testing,
    incus_network.production
  ]
}
