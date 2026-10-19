# Valores comunes generados desde client.yaml por scripts/new-client.sh (sin secretos).
account_id          = "654654616677"
region              = "us-east-1"
project             = "e2e"
environment         = "dev"
blueprint           = "saas-t3"
owner               = "samir"
cost_center         = "catalog-test"
data_classification = "internal"
extra_tags          = {}

# --- Bootstrap ---
github_org           = "sam1rC"
github_repo          = "e2e-infra"
github_environment   = "dev"
create_oidc_provider = true
artifacts_bucket     = true
# kms_admin_principal_arns = ["arn:aws:iam::<cuenta>:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_..."]
