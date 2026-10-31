resource "aws_s3_bucket" "reports" {
  bucket        = "lab3-meetings-reports-${var.account_id}"
  force_destroy = true
}

resource "aws_sqs_queue" "report_requests" {
  name                      = "lab3-meetings-report-requests"
  message_retention_seconds = 345600
  visibility_timeout_seconds = 360
}
