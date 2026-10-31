output "user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.client.id
}

output "reports_bucket_name" {
  value = aws_s3_bucket.reports.bucket
}

output "reports_queue_url" {
  value = aws_sqs_queue.report_requests.id
}
