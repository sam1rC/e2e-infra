# saas-t1 / control-plane

Control plane de SaaS T1 (SaaS Lens): user pools por tier o por tenant, registro de tenants, Lambda de onboarding, bus de eventos con metering por tenant (Firehose con partición dinámica) y su backup.

El onboarding da de alta al tenant en el registro, crea sus usuarios con `custom:tenant_id` y, para un tenant silo, dispara el pipeline de despliegue (GitHub Actions `workflow_dispatch` con una GitHub App cuya clave se carga a mano en el secreto que crea esta capa). El app plane (otra cuenta) recibe `issuers` y `event_bus_arn` como variables.

## Uso

Composición de referencia (equivale a `live/<env>/control-plane` de la fase 10): [`../examples/complete/control-plane`](../examples/complete/control-plane).

- **Lee de SSM:** —
- **Publica en SSM:** `control-plane/issuers`, `control-plane/event_bus_arn`, `control-plane/registry_table_name` y lo de sus módulos.

Visión general del blueprint, orden de despliegue y objetivos de resiliencia: [`../README.md`](../README.md). Composición entre capas: ADR [0016](../../../docs/adr/0016-blueprint-composition.md).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.30, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.68.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_alarms"></a> [alarms](#module\_alarms) | ../../../modules/observability/alarms | n/a |
| <a name="module_backup"></a> [backup](#module\_backup) | ../../../modules/resilience/backup-plan | n/a |
| <a name="module_backup_kms"></a> [backup\_kms](#module\_backup\_kms) | ../../../modules/foundation/kms-key | n/a |
| <a name="module_dashboard"></a> [dashboard](#module\_dashboard) | ../../../modules/observability/dashboard | n/a |
| <a name="module_events"></a> [events](#module\_events) | ../../../modules/integration/eventbridge-bus | n/a |
| <a name="module_kms"></a> [kms](#module\_kms) | ../../../modules/foundation/kms-key | n/a |
| <a name="module_metering_bucket"></a> [metering\_bucket](#module\_metering\_bucket) | ../../../modules/storage/s3-bucket | n/a |
| <a name="module_metering_stream"></a> [metering\_stream](#module\_metering\_stream) | ../../../modules/integration/firehose-to-s3 | n/a |
| <a name="module_onboarding"></a> [onboarding](#module\_onboarding) | ../../../modules/compute/lambda-function | n/a |
| <a name="module_pools"></a> [pools](#module\_pools) | ../../../modules/identity/cognito-user-pool | n/a |
| <a name="module_registry"></a> [registry](#module\_registry) | ../../../modules/data/dynamodb-table | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_secretsmanager_secret.github_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_ssm_parameter.layer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alarm_emails"></a> [alarm\_emails](#input\_alarm\_emails) | Correos suscritos a las alarmas del control plane. En prod, al menos uno. | `list(string)` | `[]` | no |
| <a name="input_app_account_ids"></a> [app\_account\_ids](#input\_app\_account\_ids) | Cuentas del app plane (app-nonprod, app-prod y silos) autorizadas a publicar eventos de uso (metering) en el bus del control plane. | `list(string)` | `[]` | no |
| <a name="input_auth"></a> [auth](#input\_auth) | Configuración común de los user pools: callback\_urls/logout\_urls del app client web, feature\_plan (PLUS en T1: threat protection) y email (en prod, SES con sending\_account = DEVELOPER). | <pre>object({<br/>    callback_urls = list(string)<br/>    logout_urls   = optional(list(string), [])<br/>    feature_plan  = optional(string, "PLUS")<br/>    email = optional(object({<br/>      sending_account    = optional(string, "COGNITO_DEFAULT")<br/>      source_arn         = optional(string)<br/>      from_email_address = optional(string)<br/>      reply_to           = optional(string)<br/>    }), {})<br/>  })</pre> | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_onboarding_function"></a> [onboarding\_function](#input\_onboarding\_function) | Código de la Lambda de onboarding (alta en el registro, usuarios con custom:tenant\_id y disparo del pipeline de los tenants silo): paquete zip (s3\_bucket + s3\_key, runtime, handler) o image\_uri por digest. | <pre>object({<br/>    s3_bucket         = optional(string)<br/>    s3_key            = optional(string)<br/>    s3_object_version = optional(string)<br/>    runtime           = optional(string, "python3.13")<br/>    handler           = optional(string, "app.handler")<br/>    image_uri         = optional(string)<br/>    timeout_seconds   = optional(number, 60)<br/>  })</pre> | n/a | yes |
| <a name="input_pool_strategy"></a> [pool\_strategy](#input\_pool\_strategy) | Estrategia de identidad del SaaS Lens: per\_tier (un user pool por tier, p. ej. basic/pro/premium) o per\_tenant (un pool por tenant, para tenants con requisitos propios de MFA, federación o región). | `string` | `"per_tier"` | no |
| <a name="input_pools"></a> [pools](#input\_pools) | Claves de los user pools: tiers (per\_tier) o IDs de tenant (per\_tenant), minúsculas y dígitos (máx. 24). Quitar una clave borra su pool y sus usuarios (en prod lo impide deletion\_protection). | `list(string)` | <pre>[<br/>  "basic",<br/>  "pro",<br/>  "premium"<br/>]</pre> | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto (cliente); prefijo de los nombres de recursos y de las rutas SSM. | `string` | n/a | yes |
| <a name="input_silo_pipeline"></a> [silo\_pipeline](#input\_silo\_pipeline) | Pipeline que despliega la infraestructura de un tenant silo (GitHub Actions workflow\_dispatch con una GitHub App, nunca un token personal): repositorio owner/repo y workflow. La clave privada de la App se guarda a mano en el secreto que crea esta capa. null = sin tenants silo. | <pre>object({<br/>    repository = string<br/>    workflow   = string<br/>  })</pre> | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales para los recursos (las obligatorias van en default\_tags del provider, en live/). | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_event_bus_arn"></a> [event\_bus\_arn](#output\_event\_bus\_arn) | Bus del control plane: el app plane publica aquí los eventos de uso (metering\_bus\_arn de app-app). |
| <a name="output_github_app_secret_arn"></a> [github\_app\_secret\_arn](#output\_github\_app\_secret\_arn) | Secreto donde cargar a mano la clave privada de la GitHub App; null sin pipeline de silos. |
| <a name="output_issuers"></a> [issuers](#output\_issuers) | Emisores de JWT aceptados por el app plane. |
| <a name="output_metering_bucket_id"></a> [metering\_bucket\_id](#output\_metering\_bucket\_id) | Bucket de metering (usage/tenant\_id=<id>/yyyy/MM/dd/). |
| <a name="output_onboarding_function_name"></a> [onboarding\_function\_name](#output\_onboarding\_function\_name) | Lambda de onboarding. |
| <a name="output_registry_table_name"></a> [registry\_table\_name](#output\_registry\_table\_name) | Tabla del registro de tenants. |
| <a name="output_user_pools"></a> [user\_pools](#output\_user\_pools) | User pools por clave (tier o tenant): ID, ARN, emisor de los JWT y app client web. El app plane recibe los emisores como variable (jwt\_issuers). |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- La identidad vive en el control plane (A8). Pools en `PLUS` con threat protection (`ENFORCED` en prod) y MFA `ON` en prod.
- El bus solo admite `PutEvents` de las cuentas del app plane listadas (`app_account_ids`).
- La Lambda de onboarding tiene permisos explícitos sobre los pools, el registro, el bus y (opcional) el secreto de la GitHub App; nunca un token personal.
- Registro con PITR y AWS Backup `enterprise` (vault bloqueado en prod).

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
