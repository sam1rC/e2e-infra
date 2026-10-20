data "aws_iam_policy_document" "s3" {
  statement {
    sid       = "AllowBucketsOfAllowedAccounts"
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["*"] # Acotado por aws:ResourceAccount: solo buckets de las cuentas permitidas

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceAccount"
      values   = local.s3_allowed_accounts
    }
  }

  statement {
    sid     = "AllowEcrLayerAndExtraBuckets"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = concat(
      [for arn in concat([local.ecr_layer_bucket_arn], var.s3_additional_bucket_arns) : "${arn}/*"],
    )

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

data "aws_iam_policy_document" "dynamodb" {
  statement {
    sid       = "AllowTablesOfThisAccount"
    effect    = "Allow"
    actions   = ["dynamodb:*"]
    resources = ["arn:${local.partition}:dynamodb:${local.region}:${local.account_id}:table/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = toset(var.gateway_services)

  vpc_id            = var.vpc_id
  service_name      = "${local.service_prefix}.${each.key}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids
  policy            = each.key == "s3" ? data.aws_iam_policy_document.s3.json : data.aws_iam_policy_document.dynamodb.json

  tags = merge(var.tags, { Name = "${local.name}-${each.key}" })
}
