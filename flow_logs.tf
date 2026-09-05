# Network-level visibility: every accepted and rejected flow in the VPC.
# S3 destination needs no IAM role (iam_role_arn is only for CloudWatch Logs);
# the bucket policy is what authorises delivery.logs.amazonaws.com to write.
resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = aws_s3_bucket.logs.arn

  # Nothing here references the policy, so Terraform would otherwise be free to
  # create the flow log first and see delivery fail with "Access error".
  depends_on = [aws_s3_bucket_policy.logs]

  tags = {
    Name = "secure-landing-zone-vpc-flow-logs"
  }
}
