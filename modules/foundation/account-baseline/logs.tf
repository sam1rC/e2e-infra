module "log_bucket" {
  source = "../../storage/s3-bucket"
  count  = local.create_log_destination ? 1 : 0

  project     = var.project
  environment = var.environment
  purpose     = "logs"
  bucket_name = "${local.name}-security-logs-${local.account_id}"
  kms_key_arn = module.kms.key_arn

  lifecycle_config = {
    expiration_days            = var.log_retention_days
    noncurrent_expiration_days = 30
  }

  policy_statements = [
    {
      sid            = "AWSCloudTrailAclCheck"
      actions        = ["s3:GetBucketAcl"]
      resource_paths = [""]
      principals     = [{ type = "Service", identifiers = ["cloudtrail.amazonaws.com"] }]
      conditions     = [{ test = "StringEquals", variable = "aws:SourceArn", values = [local.trail_arn] }]
    },
    {
      sid            = "AWSCloudTrailWrite"
      actions        = ["s3:PutObject"]
      resource_paths = ["/AWSLogs/${local.account_id}/*"]
      principals     = [{ type = "Service", identifiers = ["cloudtrail.amazonaws.com"] }]
      conditions = [
        { test = "StringEquals", variable = "s3:x-amz-acl", values = ["bucket-owner-full-control"] },
        { test = "StringEquals", variable = "aws:SourceArn", values = [local.trail_arn] },
      ]
    },
    {
      sid            = "AWSConfigBucketPermissionsCheck"
      actions        = ["s3:GetBucketAcl", "s3:ListBucket"]
      resource_paths = [""]
      principals     = [{ type = "Service", identifiers = ["config.amazonaws.com"] }]
      conditions     = [{ test = "StringEquals", variable = "aws:SourceAccount", values = [local.account_id] }]
    },
    {
      sid            = "AWSConfigBucketDelivery"
      actions        = ["s3:PutObject"]
      resource_paths = ["/AWSLogs/${local.account_id}/Config/*"]
      principals     = [{ type = "Service", identifiers = ["config.amazonaws.com"] }]
      conditions = [
        { test = "StringEquals", variable = "s3:x-amz-acl", values = ["bucket-owner-full-control"] },
        { test = "StringEquals", variable = "aws:SourceAccount", values = [local.account_id] },
      ]
    },
  ]

  tags = var.tags
}
