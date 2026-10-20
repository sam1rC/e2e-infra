# La key policy no puede citar el ARN de la distribución: la distribución depende del bucket y el bucket de
# la clave (ciclo). Se acota a las distribuciones de esta cuenta con ArnLike.
data "aws_iam_policy_document" "key_cloudfront" {
  count = local.create_kms ? 1 : 0

  statement {
    sid       = "AllowCloudFrontToDecryptOrigin"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${local.partition}:cloudfront::${local.account_id}:distribution/*"]
    }
  }
}

module "kms" {
  source = "../../foundation/kms-key"
  count  = local.create_kms ? 1 : 0

  project     = var.project
  environment = var.environment
  purpose     = "static-site"
  description = "CMK del bucket del sitio estático de ${var.project}/${var.environment}"

  additional_policy_documents = [data.aws_iam_policy_document.key_cloudfront[0].json]

  tags = var.tags
}

module "bucket" {
  source = "../../storage/s3-bucket"

  project       = var.project
  environment   = var.environment
  purpose       = "static-site"
  kms_key_arn   = local.kms_key_arn
  force_destroy = var.force_destroy

  policy_statements = [local.cloudfront_read_statement]

  tags = var.tags
}
