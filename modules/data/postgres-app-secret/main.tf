# Sin contraseña real en el código ni en el estado: la versión inicial solo lleva los datos de conexión
# (contraseña vacía) y la primera rotación, tras el bootstrap SQL (fase 8.4), fija la credencial con el
# usuario maestro.
resource "aws_secretsmanager_secret" "app_runtime" {
  name                    = "${var.name}/app_runtime"
  description             = "Credencial del usuario de aplicación de ${var.name} (no es el usuario maestro). La rellena el bootstrap SQL y la rota Secrets Manager."
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = local.recovery_window_in_days

  tags = merge(var.tags, { Name = "${var.name}-app-runtime" })
}

# Versión inicial (AWSCURRENT): Secrets Manager no programa la rotación de un secreto sin versión ("can't test
# rotation for this secret because it doesn't have an AWSCURRENT version", sandbox 2026-10-14). Write-only:
# no queda en el estado y las rotaciones posteriores no generan drift.
resource "aws_secretsmanager_secret_version" "initial" {
  secret_id = aws_secretsmanager_secret.app_runtime.id
  secret_string_wo = jsonencode({
    engine    = "postgres"
    host      = var.db_host
    port      = var.db_port
    dbname    = var.db_name
    username  = var.app_username
    password  = ""
    masterarn = var.master_secret_arn
  })
  secret_string_wo_version = 1
}

# Log group de la función de rotación creado antes que ella, con la CMK y retención (Lambda lo crearía sin
# cifrar, sin caducidad y fuera del estado; detectado en la sandbox el 2026-10-14). La CMK debe autorizar a
# logs.<región>.amazonaws.com.
resource "aws_cloudwatch_log_group" "rotation" {
  count = local.rotation_enabled ? 1 : 0

  name              = "/aws/lambda/${local.rotation_function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# Rotación multiusuario con la función que CloudFormation genera y mantiene (HostedRotationLambda,
# PostgreSQLMultiUser). Las plantillas de rotación del Serverless Application Repository ya no son
# accesibles desde otras cuentas (AccessDenied en GetApplication y CreateCloudFormationChangeSet, comprobado en
# la sandbox el 2026-10-14). La pila gestiona también la programación de la rotación del secreto.
resource "aws_cloudformation_stack" "rotation" {
  count = local.rotation_enabled ? 1 : 0

  #checkov:skip=CKV_AWS_124:La pila solo cambia con un apply de OpenTofu, que ya informa del resultado; los fallos de rotación los notifica Secrets Manager, no los eventos de la pila.

  name         = "${var.name}-rotation"
  capabilities = ["CAPABILITY_IAM", "CAPABILITY_AUTO_EXPAND"]

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Transform                = "AWS::SecretsManager-2024-09-16"
    Resources = {
      RotationSchedule = {
        Type = "AWS::SecretsManager::RotationSchedule"
        Properties = {
          SecretId = aws_secretsmanager_secret.app_runtime.arn
          # El secreto está vacío hasta que el bootstrap SQL lo rellena: una rotación inmediata fallaría.
          RotateImmediatelyOnUpdate = false
          HostedRotationLambda = {
            RotationType          = "PostgreSQLMultiUser"
            RotationLambdaName    = local.rotation_function_name
            MasterSecretArn       = var.master_secret_arn
            MasterSecretKmsKeyArn = var.kms_key_arn
            KmsKeyArn             = var.kms_key_arn
            VpcSubnetIds          = join(",", var.rotation.subnet_ids)
            VpcSecurityGroupIds   = aws_security_group.rotation[0].id
          }
          RotationRules = {
            AutomaticallyAfterDays = var.rotation.automatically_after_days
          }
        }
      }
    }
    Outputs = {
      RotationLambdaARN = {
        Value = { "Fn::Sub" = "arn:$${AWS::Partition}:lambda:$${AWS::Region}:$${AWS::AccountId}:function:${local.rotation_function_name}" }
      }
    }
  })

  tags = var.tags

  # La regla de entrada a la base de datos y la salida al endpoint deben existir antes de que la función pueda
  # rotar; y al destruir, la pila (con sus ENI) se borra antes que las reglas y el SG.
  depends_on = [
    aws_cloudwatch_log_group.rotation,
    aws_secretsmanager_secret_version.initial,
    aws_vpc_security_group_egress_rule.rotation_to_db,
    aws_vpc_security_group_egress_rule.rotation_to_secretsmanager,
    aws_vpc_security_group_ingress_rule.db_from_rotation,
  ]
}
