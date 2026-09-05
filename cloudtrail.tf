resource "aws_cloudtrail" "main" {
  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  # The trail validates it can write to the bucket at creation time, so the
  # policy must already be in place.
  depends_on = [aws_s3_bucket_policy.logs]

  tags = {
    Name = local.trail_name
  }
}
