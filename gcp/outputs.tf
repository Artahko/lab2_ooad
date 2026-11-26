output "api_url" {
  description = "Cloud Run URL of the API (Firebase Hosting rewrites /api/** to it)"
  value       = google_cloud_run_v2_service.api.uri
}

output "image" {
  description = "Where to push the backend image before apply"
  value       = local.image
}

output "db_connection_name" {
  description = "For the Cloud SQL Auth Proxy: cloud-sql-proxy <this>"
  value       = google_sql_database_instance.db.connection_name
}

output "database_url_secret" {
  value = google_secret_manager_secret.database_url.secret_id
}
