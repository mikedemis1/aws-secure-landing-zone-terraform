# Central log archive: CloudTrail and VPC flow logs land here, partitioned by AWS
# under AWSLogs/<account>/CloudTrail/ and AWSLogs/<account>/vpcflowlogs/.
# One bucket, one policy, one lifecycle; split only when retention or readers diverge.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  trail_name = "${var.project_name}-trail"
  # Built as a string (not aws_cloudtrail.main.arn) to avoid a cycle: the trail
  # depends on the policy, and the policy pins the trail.
  trail_arn = "arn:aws:cloudtrail:${local.region}:${local.account_id}:trail/${local.trail_name}"
  # Flow logs are delivered through the CloudWatch "vended logs" pipeline, so the
  # source ARN is the logs service, not the VPC or the flow-log resource.
  log_delivery_arn = "arn:aws:logs:${local.region}:${local.account_id}:*"
}

resource "aws_s3_bucket" "logs" {
  bucket = "${var.project_name}-logs-${random_id.suffix.hex}"

  # Lab setting: lets `terraform destroy` remove a versioned bucket that has
  # objects in it. Never set this on a production log archive.
  force_destroy = true

  tags = {
    Name = "${var.project_name}-logs"
  }
}

# ACLs disabled: the bucket owner owns every object, access is governed by the
# bucket policy only. This is the AWS default for new buckets; stated explicitly
# so the decision is visible.
resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Retention is a decision, not an accident. Versioning exists to survive
# overwrite/tamper, not to hoard forever.
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  depends_on = [aws_s3_bucket_versioning.logs]

  rule {
    id     = "log-retention"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# A bucket has exactly one policy, so every service that writes here gets its
# statements in this single resource.
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Deny + Principal "*" is the one place a wildcard principal is safe: a Deny
      # can only shrink access. Both the bucket ARN (ListBucket, GetBucketAcl) and
      # the object ARN are needed, or half the API surface stays uncovered.
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.logs.arn,
          "${aws_s3_bucket.logs.arn}/*",
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      # CloudTrail: aws:SourceArn pins the exact trail (confused-deputy guard).
      # The account is already inside the ARN, so no SourceAccount is needed.
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.logs.arn
        Condition = {
          StringEquals = { "aws:SourceArn" = local.trail_arn }
        }
      },
      # Resource stays at AWSLogs/<account>/* because digests land in
      # CloudTrail-Digest/, not only in CloudTrail/.
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/AWSLogs/${local.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "aws:SourceArn" = local.trail_arn
          }
        }
      },
      # VPC flow logs: the source ARN is a wildcard on the logs service, so
      # SourceAccount is what actually pins the account here.
      {
        Sid       = "AWSLogDeliveryAclCheck"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.logs.arn
        Condition = {
          StringEquals = { "aws:SourceAccount" = local.account_id }
          ArnLike      = { "aws:SourceArn" = local.log_delivery_arn }
        }
      },
      # Narrowed to the vpcflowlogs/ prefix (AWS's template uses AWSLogs/<account>/*).
      {
        Sid       = "AWSLogDeliveryWrite"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/AWSLogs/${local.account_id}/vpcflowlogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "aws:SourceAccount" = local.account_id
          }
          ArnLike = { "aws:SourceArn" = local.log_delivery_arn }
        }
      },
    ]
  })
}

resource "random_id" "suffix" {
  byte_length = 4
}
