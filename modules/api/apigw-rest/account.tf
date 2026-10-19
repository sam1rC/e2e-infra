# Rol de CloudWatch de API Gateway: ajuste único por cuenta y región (lo usan todas las REST APIs).
data "aws_iam_policy_document" "account_logging_assume" {
  count = var.manage_account_logging_role ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "account_logging" {
  count = var.manage_account_logging_role ? 1 : 0

  name               = "${var.project}-${var.environment}-apigw-cloudwatch"
  description        = "API Gateway escribe los logs de acceso y ejecucion de las REST APIs de la cuenta"
  assume_role_policy = data.aws_iam_policy_document.account_logging_assume[0].json

  tags = var.tags
}

# Excepción al ADR 0012: el rol es de toda la cuenta y escribe en log groups de cualquier API, así que
# la política gestionada de AWS (solo logs:*) es la que corresponde.
resource "aws_iam_role_policy_attachment" "account_logging" {
  count = var.manage_account_logging_role ? 1 : 0

  role       = aws_iam_role.account_logging[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "this" {
  count = var.manage_account_logging_role ? 1 : 0

  cloudwatch_role_arn = aws_iam_role.account_logging[0].arn

  depends_on = [aws_iam_role_policy_attachment.account_logging]
}
