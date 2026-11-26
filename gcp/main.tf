# Spry's core on Google Cloud: Artifact Registry + Cloud Run (API) + Cloud SQL (PostgreSQL)
# + Secret Manager. The frontend goes to Firebase Hosting (firebase.json in the repo root).
# Sign-in (Cognito), the weekly report (SQS/S3) and the agenda parser (Bedrock) stay on AWS.

locals {
  name = var.project_name
  services = [
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "firebasehosting.googleapis.com",
  ]
  image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.backend.repository_id}/backend:${var.image_tag}"
}

# --- APIs are off in a new project: enable them here, so a fresh project is reproducible ---

resource "google_project_service" "enabled" {
  for_each = toset(local.services)

  service            = each.value
  disable_on_destroy = false
}

# --- Container registry (the ECR counterpart) ---

resource "google_artifact_registry_repository" "backend" {
  repository_id = "${local.name}-backend"
  location      = var.region
  format        = "DOCKER"
  description   = "Backend images for Cloud Run"

  # Keep the bill inside the 0.5 GB free tier: only the newest images survive.
  cleanup_policies {
    id     = "keep-latest-3"
    action = "KEEP"
    most_recent_versions {
      keep_count = 3
    }
  }

  depends_on = [google_project_service.enabled]
}

# --- The identity the API runs as (not the default compute account, which has Editor) ---

resource "google_service_account" "api" {
  account_id   = "${local.name}-api"
  display_name = "Spry API on Cloud Run"
}

resource "google_project_iam_member" "api_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.api.email}"
}

# --- Database: Cloud SQL for PostgreSQL (the Aurora counterpart; it does not pause) ---

resource "google_sql_database_instance" "db" {
  name             = "${local.name}-db"
  database_version = "POSTGRES_17"
  region           = var.region

  settings {
    edition           = "ENTERPRISE" # shared-core tiers exist only in the Enterprise edition
    tier              = var.db_tier
    disk_type         = "PD_SSD"
    disk_size         = 10
    disk_autoresize   = false
    activation_policy = var.db_activation_policy
    availability_type = "ZONAL"

    backup_configuration {
      enabled = false # a lab database; turn on for anything real
    }

    ip_configuration {
      # Public IP with no authorized networks: only the Cloud SQL connector
      # (Cloud Run, Cloud SQL Auth Proxy) can reach it, through IAM.
      ipv4_enabled = true
      ssl_mode     = "ENCRYPTED_ONLY"
    }
  }

  deletion_protection = false # terraform destroy must be able to remove it (see Clean up)

  depends_on = [google_project_service.enabled]
}

resource "google_sql_database" "app" {
  name     = "meetings"
  instance = google_sql_database_instance.db.name
}

resource "random_password" "db" {
  length  = 32
  special = false # it goes into a URL
}

resource "google_sql_user" "app" {
  name     = "meetings"
  instance = google_sql_database_instance.db.name
  password = random_password.db.result
}

# --- Secret Manager: the connection string (with the generated password) never enters git ---

resource "google_secret_manager_secret" "database_url" {
  secret_id = "${local.name}-database-url"

  replication {
    auto {}
  }

  depends_on = [google_project_service.enabled]
}

resource "google_secret_manager_secret_version" "database_url" {
  secret = google_secret_manager_secret.database_url.id
  # Cloud Run mounts the instance as a unix socket under /cloudsql/<connection name>.
  secret_data = "postgresql+asyncpg://${google_sql_user.app.name}:${random_password.db.result}@/${google_sql_database.app.name}?host=/cloudsql/${google_sql_database_instance.db.connection_name}"
}

resource "google_secret_manager_secret_iam_member" "api_reads_database_url" {
  secret_id = google_secret_manager_secret.database_url.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

# --- The API on Cloud Run (the Lambda + function URL counterpart) ---

resource "google_cloud_run_v2_service" "api" {
  name                = "${local.name}-api"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.api.email

    scaling {
      min_instance_count = 0 # scale to zero: idle costs nothing
      max_instance_count = 2
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.db.connection_name]
      }
    }

    containers {
      image = local.image

      # Cloud Run sends HTTP to the port in $PORT (8080); no Lambda adapter.
      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true # request-based billing: CPU only while a request is handled
      }

      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.database_url.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "DB_POOL_SIZE"
        value = "2"
      }
      env {
        name  = "DB_MAX_OVERFLOW"
        value = "2"
      }
      env {
        name  = "CORS_ORIGINS"
        value = var.cors_origins
      }
      env {
        name  = "COGNITO_USER_POOL_ID"
        value = var.cognito_user_pool_id
      }
      env {
        name  = "COGNITO_CLIENT_ID"
        value = var.cognito_client_id
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
    }
  }

  depends_on = [
    google_project_iam_member.api_cloudsql_client,
    google_secret_manager_secret_iam_member.api_reads_database_url,
    google_secret_manager_secret_version.database_url,
  ]
}

# Public invoke is allowed only because the API checks Cognito ID tokens itself
# (every route except /api/health returns 401 without one).
resource "google_cloud_run_v2_service_iam_member" "public" {
  name     = google_cloud_run_v2_service.api.name
  location = google_cloud_run_v2_service.api.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
