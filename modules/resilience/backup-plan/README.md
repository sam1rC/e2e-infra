# resilience/backup-plan

**Vault de AWS Backup** cifrado con CMK propia y, opcionalmente, su **plan** con reglas diaria (35 días), mensual (12 meses, con paso a almacenamiento frío) y **continua** (PITR gestionado por Backup para Aurora/RDS), selección por la etiqueta `BackupPlan = <tier>`, bloqueo del vault en modo compliance, **copias a otro vault** (otra región para DR o la cuenta de backup), **pruebas de restauración automáticas** y alarmas de trabajos fallidos.

Con `plan_enabled = false` el módulo crea solo el vault (y su política de copia entrante): es el modo para desplegar el **destino** de las copias en otra región o cuenta instanciando el módulo allí.

## Uso

```hcl
# Destino de las copias: otra región (provider alias)
module "vault_dr" {
  source    = "../../modules/resilience/backup-plan"
  providers = { aws = aws.dr }

  project      = "acme"
  environment  = "prod"
  name         = "dr"
  kms_key_arn  = module.kms_backup_dr.key_arn
  plan_enabled = false
  vault_lock   = { min_retention_days = 7, changeable_for_days = 3 }
}

# Origen: plan, copia a DR y pruebas de restauración
module "backup" {
  source = "../../modules/resilience/backup-plan"

  project     = "acme"
  environment = "prod"
  kms_key_arn = module.kms_backup.key_arn # via_services: backup.<región>.amazonaws.com
  tier        = "enterprise"

  vault_lock        = { min_retention_days = 7, changeable_for_days = 3 }
  copy_destinations = { dr = { vault_arn = module.vault_dr.vault_arn } }

  restore_testing = {
    metadata_overrides = {
      Aurora = { dbsubnetgroupname = "acme-prod-aurora", vpcsecuritygroupids = jsonencode(["sg-0123456789abcdef0"]) }
    }
  }

  alarm_actions = [module.alarms.topic_arn]
}
```

Más opciones en [`examples/complete`](examples/complete).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.30, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.67.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_backup_plan.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_plan) | resource |
| [aws_backup_restore_testing_plan.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_restore_testing_plan) | resource |
| [aws_backup_restore_testing_selection.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_restore_testing_selection) | resource |
| [aws_backup_selection.by_tag](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_selection) | resource |
| [aws_backup_vault.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault) | resource |
| [aws_backup_vault_lock_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_lock_configuration) | resource |
| [aws_backup_vault_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_policy) | resource |
| [aws_cloudwatch_metric_alarm.backup_jobs_failed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.copy_jobs_failed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.restore_jobs_failed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_iam_role.backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.restores](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_ssm_parameter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.vault](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alarm_actions"></a> [alarm\_actions](#input\_alarm\_actions) | ARN de los topics de SNS que reciben las alarmas de trabajos fallidos (topic\_arn de observability/alarms). Vacío crea las alarmas sin notificación (visibles solo en la consola). | `list(string)` | `[]` | no |
| <a name="input_allow_copy_from_account_ids"></a> [allow\_copy\_from\_account\_ids](#input\_allow\_copy\_from\_account\_ids) | Cuentas autorizadas a copiar recovery points a este vault (política del vault de destino: backup:CopyIntoBackupVault). Vacío = sin política. | `list(string)` | `[]` | no |
| <a name="input_copy_destinations"></a> [copy\_destinations](#input\_copy\_destinations) | Vaults de destino de las copias de las reglas diaria y mensual, por clave estable (p. ej. dr, backup-account): el vault de otra región (DR) o de la cuenta de backup, creado instanciando este módulo allí con plan\_enabled = false. retention\_days null = la retención de cada regla. | <pre>map(object({<br/>    vault_arn      = string<br/>    retention_days = optional(number)<br/>  }))</pre> | `{}` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN de la CMK propia del vault (no la clave de los datos de origen). En una cuenta o región de destino de copias, la clave de esa región. Su política debe autorizar a AWS Backup (kms:ViaService de backup). | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Nombre lógico del vault y del plan; los reales son <project>-<environment>-<name>. | `string` | `"backup"` | no |
| <a name="input_plan_enabled"></a> [plan\_enabled](#input\_plan\_enabled) | Crea el plan, la selección y el rol de servicio además del vault. false = solo vault (y su bloqueo): es el modo para el vault de destino de las copias en otra región o en la cuenta de backup, que se despliega instanciando este módulo allí. | `bool` | `true` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_publish_ssm_parameters"></a> [publish\_ssm\_parameters](#input\_publish\_ssm\_parameters) | Publica el nombre y el ARN del vault en SSM Parameter Store bajo /<project>/<env>/resilience/ para las capas consumidoras. | `bool` | `true` | no |
| <a name="input_restore_testing"></a> [restore\_testing](#input\_restore\_testing) | Pruebas de restauración automáticas (T1): plan periódico que restaura el último recovery point de cada tipo y lo da por válido tras validation\_window\_hours. metadata\_overrides, por tipo (Aurora, RDS, DynamoDB), son los parámetros de la restauración, que las bases de datos necesitan para no caer en la VPC por defecto: p. ej. Aurora { dbsubnetgroupname = ..., vpcsecuritygroupids = jsonencode([...]) }. Requiere plan\_enabled. | <pre>object({<br/>    schedule_expression     = optional(string, "cron(0 6 1 * ? *)")<br/>    recovery_window_days    = optional(number, 30)<br/>    validation_window_hours = optional(number, 1)<br/>    resource_types          = optional(list(string), ["Aurora", "RDS", "DynamoDB"])<br/>    metadata_overrides      = optional(map(map(string)), {})<br/>    start_window_hours      = optional(number, 8)<br/>  })</pre> | `null` | no |
| <a name="input_schedule"></a> [schedule](#input\_schedule) | Reglas del plan: diaria (daily\_retention\_days), mensual (monthly\_retention\_days, con paso a almacenamiento frío tras monthly\_cold\_storage\_after\_days; 0 lo desactiva; solo aplica a los tipos de recurso que lo admiten) y continua (continuous\_retention\_days, 1-35, para recuperación a un punto en el tiempo de Aurora/RDS/S3; 0 desactiva la regla). Horas en UTC. | <pre>object({<br/>    daily_retention_days            = optional(number, 35)<br/>    monthly_retention_days          = optional(number, 365)<br/>    monthly_cold_storage_after_days = optional(number, 30)<br/>    continuous_retention_days       = optional(number, 35)<br/>    daily_cron                      = optional(string, "cron(0 5 * * ? *)")<br/>    monthly_cron                    = optional(string, "cron(0 5 1 * ? *)")<br/>  })</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_tier"></a> [tier](#input\_tier) | Valor de la etiqueta BackupPlan que selecciona los recursos a proteger (enterprise, growth o starter): los módulos de datos la ponen con backup\_plan. Obligatorio con plan\_enabled = true. | `string` | `null` | no |
| <a name="input_vault_lock"></a> [vault\_lock](#input\_vault\_lock) | Bloqueo del vault en modo compliance (con changeable\_for\_days >= 3): durante esos días de enfriamiento se puede deshacer; después es IRREVERSIBLE y ni la raíz de la cuenta puede borrar recovery points antes de min\_retention\_days ni retirar el bloqueo. Obligatorio en prod para los tiers enterprise y growth. max\_retention\_days null = sin máximo. | <pre>object({<br/>    min_retention_days  = optional(number, 7)<br/>    max_retention_days  = optional(number)<br/>    changeable_for_days = optional(number, 3)<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_plan_arn"></a> [plan\_arn](#output\_plan\_arn) | ARN del plan de backup; null si plan\_enabled = false. |
| <a name="output_plan_id"></a> [plan\_id](#output\_plan\_id) | ID del plan de backup; null si plan\_enabled = false. |
| <a name="output_restore_testing_plan_arn"></a> [restore\_testing\_plan\_arn](#output\_restore\_testing\_plan\_arn) | ARN del plan de pruebas de restauración; null si restore\_testing no está configurado. |
| <a name="output_service_role_arn"></a> [service\_role\_arn](#output\_service\_role\_arn) | Rol de servicio de AWS Backup; null si plan\_enabled = false. |
| <a name="output_vault_arn"></a> [vault\_arn](#output\_vault\_arn) | ARN del vault: es el destino de copy\_destinations del vault de origen. |
| <a name="output_vault_name"></a> [vault\_name](#output\_vault\_name) | Nombre del vault. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Vault con CMK propia** (no la clave de los datos de origen) y sin acceso público. Los recovery points se protegen además con `deletion_protection` del propio servicio de Backup y, en prod T1/T2, con el bloqueo.
- **Bloqueo del vault (`vault_lock`) = modo compliance, y es IRREVERSIBLE.** Con `changeable_for_days >= 3` hay un periodo de enfriamiento en el que se puede deshacer; **pasado ese plazo, ni la raíz de la cuenta ni AWS pueden retirarlo ni borrar recovery points antes de `min_retention_days`**, y el vault no puede eliminarse mientras tenga recovery points. Es obligatorio en prod para los tiers `enterprise` y `growth` (validado) y no debe usarse en ejemplos efímeros (`examples/complete` no lo incluye). Todas las retenciones del plan deben ser al menos `min_retention_days`.
- **Reglas:** diaria y mensual con copia opcional (`copy_destinations`: el vault de otra región o de la cuenta de backup, cuyo ARN llega de una instancia del módulo con `plan_enabled = false` allí; la continua no admite copias entre regiones). La mensual pasa a frío a los 30 días solo en los tipos de recurso que lo admiten y exige 90 días más de retención (validado). La regla continua (1-35 días) da PITR a Aurora/RDS/S3; para el resto de recursos seleccionados no genera copias.
- **Selección por etiqueta** `BackupPlan = <tier>` (los módulos de datos la ponen con `backup_plan`): un recurso entra o sale del plan solo cambiando su etiqueta.
- **Rol de servicio** con las políticas gestionadas `AWSBackupServiceRolePolicyForBackup` y `...ForRestores`, como pide el plan (cubren los servicios que Backup soporta y AWS las mantiene), y trust limitado a `backup.amazonaws.com` con `aws:SourceAccount`. Es una excepción al criterio de roles a medida del ADR 0012, aceptada porque la lista de acciones por servicio es grande y cambia con cada servicio nuevo.
- **Destino entre cuentas:** `allow_copy_from_account_ids` crea la política del vault con `backup:CopyIntoBackupVault` solo para esas cuentas. La CMK del vault de destino debe permitir a la cuenta de origen (no verificado: ver pendiente).
- **Pruebas de restauración (`restore_testing`, T1):** un plan periódico (mensual por defecto) restaura el último recovery point de cada tipo (Aurora, RDS, DynamoDB por defecto) de los recursos del tier y lo da por válido tras `validation_window_hours`; el informe mensual puede citar su resultado. Las restauraciones de bases de datos necesitan `metadata_overrides` (subnet group y security groups) para no caer en la VPC por defecto. Los nombres del plan y las selecciones usan guiones bajos (restricción de AWS).
- **Alarmas** (`NumberOfBackupJobsFailed`, `NumberOfCopyJobsFailed` y `NumberOfRestoreJobsFailed`, en `AWS/Backup`) hacia `alarm_actions`; `notBreaching` sin datos.
- **SSM** (`/<project>/<env>/resilience/…`): `backup_vault_name` y `backup_vault_arn`.

### Cómo se verificó

- 31 tests unitarios con `mock_provider` (vault y CMK, reglas diaria/mensual/continua con sus ciclos de vida, regla continua y frío desactivables, selección por etiqueta, rol y políticas gestionadas, copias solo en diaria y mensual con retención por destino, modo solo vault, bloqueo compliance, política de copia entrante, pruebas de restauración con selección por tipo y etiqueta, alarmas, SSM y 13 validaciones que deben fallar). Los dos ejemplos validan y su grafo es acíclico.
- **Plan real offline** contra el provider 6.67.0 (credenciales falsas; cuenta sustituida por una constante): 16 recursos, esquema aceptado; ciclos de vida, copias, bloqueo y pruebas de restauración correctos en el plan JSON.
- **Pendiente en sandbox** (aceptación de la fase 7): un backup bajo demanda de una base etiquetada termina, su copia cross-region (T1) aparece en el vault de destino y una prueba de restauración llega a `COMPLETED`; las claves de restauración (`dbsubnetgroupname`, `vpcsecuritygroupids`) y el comportamiento del frío por tipo de recurso están tomados de la documentación de AWS; que las políticas gestionadas basten para copiar a una CMK de otra región o cuenta.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
