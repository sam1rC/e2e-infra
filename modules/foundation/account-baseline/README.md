# account-baseline

Línea base de seguridad de una cuenta AWS: bloqueo de acceso público, EBS cifrado, CloudTrail, GuardDuty, Security Hub (FSBP + CIS), AWS Config, Access Analyzer, Inspector v2, alertas y presupuesto.

## Uso

```hcl
module "baseline" {
  source = "../../modules/foundation/account-baseline"

  project      = "acme"
  environment  = "prod"
  alert_emails = ["security@example.com"]

  budget = {
    monthly_limit_usd = 1500
    alert_emails      = ["finance@example.com"]
  }
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

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_budgets"></a> [budgets](#module\_budgets) | ../budgets | n/a |
| <a name="module_kms"></a> [kms](#module\_kms) | ../kms-key | n/a |
| <a name="module_log_bucket"></a> [log\_bucket](#module\_log\_bucket) | ../../storage/s3-bucket | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_accessanalyzer_analyzer.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/accessanalyzer_analyzer) | resource |
| [aws_cloudtrail.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudtrail) | resource |
| [aws_cloudwatch_event_rule.guardduty_high](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.securityhub_high](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.guardduty_high](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.securityhub_high](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.cloudtrail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_config_configuration_recorder.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_configuration_recorder) | resource |
| [aws_config_configuration_recorder_status.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_configuration_recorder_status) | resource |
| [aws_config_delivery_channel.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_delivery_channel) | resource |
| [aws_ebs_default_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_default_kms_key) | resource |
| [aws_ebs_encryption_by_default.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_encryption_by_default) | resource |
| [aws_guardduty_detector.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/guardduty_detector) | resource |
| [aws_guardduty_detector_feature.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/guardduty_detector_feature) | resource |
| [aws_iam_account_password_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_account_password_policy) | resource |
| [aws_iam_role.cloudtrail_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.cloudtrail_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.config_delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.config_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_inspector2_enabler.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/inspector2_enabler) | resource |
| [aws_s3_account_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_account_public_access_block) | resource |
| [aws_securityhub_account.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/securityhub_account) | resource |
| [aws_securityhub_standards_subscription.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/securityhub_standards_subscription) | resource |
| [aws_sns_topic.alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.alerts_email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.alerts_topic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cloudtrail_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cloudtrail_logs_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.config_delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.config_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.key_services](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_access_analyzer_type"></a> [access\_analyzer\_type](#input\_access\_analyzer\_type) | Tipo de IAM Access Analyzer: ACCOUNT, u ORGANIZATION en la cuenta de seguridad delegada. | `string` | `"ACCOUNT"` | no |
| <a name="input_alert_emails"></a> [alert\_emails](#input\_alert\_emails) | Correos que reciben las alertas de seguridad (GuardDuty severidad >= 7 y Security Hub CRITICAL/HIGH). Cada destinatario debe confirmar la suscripción SNS. | `list(string)` | n/a | yes |
| <a name="input_budget"></a> [budget](#input\_budget) | Presupuesto mensual y detección de anomalías (módulo budgets). null = no se crea. | <pre>object({<br/>    monthly_limit_usd     = number<br/>    alert_emails          = list(string)<br/>    anomaly_threshold_usd = optional(number, 100)<br/>  })</pre> | `null` | no |
| <a name="input_cloudtrail"></a> [cloudtrail](#input\_cloudtrail) | Opciones de CloudTrail. s3\_data\_events registra el acceso a objetos de todos los buckets (coste por evento). | <pre>object({<br/>    s3_data_events = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_guardduty_features"></a> [guardduty\_features](#input\_guardduty\_features) | Protecciones opcionales de GuardDuty. | <pre>object({<br/>    s3_data_events         = optional(bool, true)<br/>    ebs_malware_protection = optional(bool, true)<br/>    rds_login_events       = optional(bool, true)<br/>    lambda_network_logs    = optional(bool, true)<br/>    eks_audit_logs         = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_inspector_resource_types"></a> [inspector\_resource\_types](#input\_inspector\_resource\_types) | Tipos de recurso que escanea Amazon Inspector v2. | `list(string)` | <pre>[<br/>  "ECR",<br/>  "LAMBDA"<br/>]</pre> | no |
| <a name="input_log_archive"></a> [log\_archive](#input\_log\_archive) | Destino externo de logs (cuenta Log Archive en SaaS T1). Si es null, el módulo crea un bucket y una CMK locales. El bucket externo debe tener ya la política que permite escribir a CloudTrail y Config de esta cuenta, y su clave debe permitirles cifrar. | <pre>object({<br/>    bucket_name = string<br/>    kms_key_arn = string<br/>  })</pre> | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Días que se conservan los logs de CloudTrail y Config en el bucket local (también la retención del grupo de CloudWatch Logs de CloudTrail, ajustada al valor admitido más cercano). | `number` | `365` | no |
| <a name="input_password_policy"></a> [password\_policy](#input\_password\_policy) | Política de contraseñas IAM (por si existen usuarios humanos; lo recomendado es IAM Identity Center). | <pre>object({<br/>    minimum_length  = optional(number, 14)<br/>    max_age_days    = optional(number, 90)<br/>    reuse_prevented = optional(number, 24)<br/>  })</pre> | `{}` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_security_hub_standards"></a> [security\_hub\_standards](#input\_security\_hub\_standards) | Estándares de Security Hub a suscribir. Verifica las versiones disponibles con `aws securityhub describe-standards` antes de cambiarlas. | <pre>object({<br/>    foundational     = optional(bool, true)<br/>    foundational_ver = optional(string, "1.0.0")<br/>    cis              = optional(bool, true)<br/>    cis_ver          = optional(string, "5.0.0")<br/>  })</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alerts_topic_arn"></a> [alerts\_topic\_arn](#output\_alerts\_topic\_arn) | ARN del tópico SNS cifrado de alertas de seguridad. |
| <a name="output_guardduty_detector_id"></a> [guardduty\_detector\_id](#output\_guardduty\_detector\_id) | ID del detector de GuardDuty. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN de la CMK de la línea base (logs, alertas y EBS por defecto). |
| <a name="output_log_bucket_name"></a> [log\_bucket\_name](#output\_log\_bucket\_name) | Bucket que recibe los logs de CloudTrail y Config (local o externo). |
| <a name="output_trail_arn"></a> [trail\_arn](#output\_trail\_arn) | ARN del trail multi-región. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

Se aplica **una vez por cuenta y región** (`live/_baseline/<account>/`). No crea usuarios IAM: el acceso humano va por IAM Identity Center (ver `docs/runbooks/identity-center.md`).

- **Bloqueo de acceso público a nivel de cuenta**, cifrado EBS por defecto con la CMK de la línea base y política de contraseñas IAM (14+ caracteres) por si existieran usuarios locales.
- **CloudTrail** multi-región con validación de ficheros, eventos de gestión de lectura y escritura, cifrado con CMK y copia a CloudWatch Logs cifrada (requisito de CIS). Los eventos de datos de S3 son opcionales por su coste.
- **Logs inmutables en origen:** el bucket local es versionado, SSE-KMS, TLS ≥ 1.2 y solo escribible por CloudTrail y Config de esta cuenta (con `aws:SourceArn`/`aws:SourceAccount`). En SaaS T1 usa `log_archive` para enviarlos a la cuenta Log Archive: el bucket y la clave de allí deben autorizar a esta cuenta.
- **GuardDuty** con publicación cada 15 minutos y protecciones de S3, malware de EBS, login de RDS y red de Lambda (EKS opcional).
- **Security Hub** con *solo* los estándares AWS Foundational Security Best Practices 1.0.0 y CIS AWS Foundations 5.0.0, que se habilitan tras AWS Config (muchos controles lo necesitan). **Los ARN de los estándares no se han verificado contra `aws securityhub describe-standards`:** compruébalos antes del primer apply.
- **AWS Config** graba todos los tipos soportados y entrega a la misma ubicación cifrada.
- **Access Analyzer** de cuenta (u organización en la cuenta de seguridad delegada) e **Inspector v2** para ECR y Lambda.
- **Alertas:** hallazgos de GuardDuty con severidad ≥ 7 y de Security Hub CRITICAL/HIGH nuevos y activos van a un tópico SNS cifrado con la CMK. Cada destinatario debe **confirmar la suscripción** por correo. La política del tópico solo permite publicar a las dos reglas de EventBridge.
- La key policy añade declaraciones exactas para CloudTrail (con `aws:SourceArn` y contexto de cifrado), CloudWatch Logs y EventBridge; el resto del acceso se concede por IAM.

### Límites conocidos

- Es **regional**: GuardDuty, Security Hub, Config e Inspector solo cubren la región donde se aplica. La restricción de regiones de `org-guardrails` evita actividad en las demás.
- **Agregación de organización** (administrador delegado de GuardDuty/Security Hub/Config) no se configura aquí; se hace en la cuenta de management y la cuenta `security` de SaaS T1.
- Las SCP de `org-guardrails` impiden `cloudtrail:UpdateTrail` o `guardduty:UpdateDetector` a cualquier rol no exento: el rol que aplica este módulo debe estar en `admin_role_arns`.
- Con `s3_data_events` activo, el coste de CloudTrail crece con el tráfico de S3 de toda la cuenta.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
