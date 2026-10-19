locals {
  oidc_host  = "token.actions.githubusercontent.com"
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  github_environment = coalesce(var.github_environment, var.environment)
  repo_slug          = "${var.github_org}/${var.github_repo}"

  plan_role_name       = "${var.name_prefix}-plan-${var.environment}"
  apply_role_name      = "${var.name_prefix}-apply-${var.environment}"
  boundary_policy_name = "${var.project}-${var.environment}-${var.name_prefix}-apply-boundary"

  # ARNs construidos por nombre (no por referencia) para que la boundary pueda proteger
  # los roles a los que se adjunta sin crear un ciclo de dependencias.
  plan_role_arn       = "arn:${local.partition}:iam::${local.account_id}:role/${local.plan_role_name}"
  apply_role_arn      = "arn:${local.partition}:iam::${local.account_id}:role/${local.apply_role_name}"
  boundary_policy_arn = "arn:${local.partition}:iam::${local.account_id}:policy/${local.boundary_policy_name}"

  provider_arn = var.create_provider ? aws_iam_openid_connect_provider.this[0].arn : data.aws_iam_openid_connect_provider.existing[0].arn

  # Prefijo de las claves de estado: <env>/<layer>/terraform.tfstate (+ .tflock)
  state_prefix = "${var.environment}/"

  plan_subjects = [
    "repo:${local.repo_slug}:pull_request",
    "repo:${local.repo_slug}:ref:refs/heads/${var.main_branch}",
  ]
  apply_subjects = ["repo:${local.repo_slug}:environment:${local.github_environment}"]
}
