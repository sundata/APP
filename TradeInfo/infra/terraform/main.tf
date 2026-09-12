# SimpleMarket GCP infrastructure (REQUIREMENTS §65, T43).
# Single-file MVP layout; split into modules/ when the footprint grows.

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  backend "gcs" {
    bucket = "simplemarket-tfstate"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" { type = string }
variable "region"     { type = string, default = "asia-east1" }
variable "env"        { type = string, default = "staging" }
variable "db_password" {
  type      = string
  sensitive = true
}

# --- Cloud SQL Postgres (§20) ---
resource "google_sql_database_instance" "pg" {
  name             = "simplemarket-${var.env}"
  database_version = "POSTGRES_15"
  region           = var.region
  settings {
    tier              = "db-f1-micro" # MVP; scale up before prod
    availability_type = "ZONAL"
    backup_configuration {
      enabled    = true
      start_time = "03:00" # daily backup (§68)
    }
    ip_configuration {
      ipv4_enabled = true
      # Cloud Run connects via the Cloud SQL connector, not public IP
    }
  }
  deletion_protection = var.env == "prod"
}

resource "google_sql_database" "db" {
  name     = "simplemarket"
  instance = google_sql_database_instance.pg.name
}

resource "google_sql_user" "app" {
  name     = "simplemarket"
  instance = google_sql_database_instance.pg.name
  password = var.db_password
}

# --- Memorystore Redis (§20 snapshot cache / WS fanout) ---
resource "google_redis_instance" "cache" {
  name           = "simplemarket-${var.env}"
  tier           = "BASIC"
  memory_size_gb = 1
  region         = var.region
}

# --- BigQuery tick sink (§28) ---
resource "google_bigquery_dataset" "ticks" {
  dataset_id = "simplemarket_ticks"
  location   = var.region
}

resource "google_bigquery_table" "market_ticks" {
  dataset_id = google_bigquery_dataset.ticks.dataset_id
  table_id   = "market_ticks"
  time_partitioning {
    type  = "DAY"
    field = "quote_ts"
  }
  schema = jsonencode([
    { name = "asset_id", type = "STRING", mode = "REQUIRED" },
    { name = "price", type = "NUMERIC", mode = "REQUIRED" },
    { name = "quote_ts", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "source_id", type = "STRING", mode = "NULLABLE" },
    { name = "ingested_at", type = "TIMESTAMP", mode = "REQUIRED" },
  ])
}

# --- Secret Manager ---
resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "simplemarket-jwt-${var.env}"
  replication { auto {} }
}

# --- Cloud Run: API ---
resource "google_cloud_run_v2_service" "api" {
  name     = "simplemarket-api-${var.env}"
  location = var.region
  template {
    scaling {
      min_instance_count = var.env == "prod" ? 1 : 0
      max_instance_count = 10
    }
    containers {
      image = "gcr.io/${var.project_id}/simplemarket-api:latest"
      env {
        name  = "SIMPLEMARKET_ENV"
        value = var.env
      }
      env {
        name = "SIMPLEMARKET_SECRET_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_secret.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "SIMPLEMARKET_DATABASE_URL"
        # Cloud SQL connector socket path
        value = "postgresql+psycopg://simplemarket@${google_sql_database_instance.pg.name}/simplemarket"
      }
      env {
        name  = "SIMPLEMARKET_REDIS_URL"
        value = "redis://${google_redis_instance.cache.host}:${google_redis_instance.cache.port}/0"
      }
    }
  }
}

# --- Cloud Scheduler: collector triggers ---
resource "google_cloud_scheduler_job" "market_collector" {
  name      = "collect-market-${var.env}"
  schedule  = "* * * * *" # 1m cadence for crypto/market open hours
  time_zone = "UTC"
  http_target {
    http_method = "POST"
    uri         = "${google_cloud_run_v2_service.api.uri}/internal/collect/market"
    oidc_token {
      service_account_email = google_service_account.scheduler.email
    }
  }
}

resource "google_service_account" "scheduler" {
  account_id = "simplemarket-scheduler-${var.env}"
}

# --- Budget alert (§69) ---
resource "google_billing_budget" "monthly" {
  billing_account = var.billing_account
  display_name    = "simplemarket-${var.env}"
  amount {
    specified_amount {
      currency_code = "USD"
      units         = "50" # MVP monthly cap
    }
  }
  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
}

variable "billing_account" { type = string }

output "api_url"  { value = google_cloud_run_v2_service.api.uri }
output "redis_host" { value = google_redis_instance.cache.host }
