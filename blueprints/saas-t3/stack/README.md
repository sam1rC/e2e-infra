# saas-t3 / stack

Capa única de SaaS T3 (pool serverless): sitio estático + CloudFront, REST API con autorizador de Cognito y planes de uso por tier, WAF regional con verificación de origen, Lambda, user pool compartido con `custom:tenant_id`, tabla DynamoDB con partición por tenant y rol ABAC (token vending machine).

Requiere los providers `aws` y `aws.us_east_1`. La Lambda no tiene acceso directo a la tabla: asume el rol del tenant con la etiqueta de sesión del tenant del JWT y debe cachear esas credenciales por tenant. El onboarding crea las API keys y las asocia al plan de su tier (`usage_plan_id/<tier>` en SSM).

## Uso

Composición de referencia (equivale a `live/<env>/stack` de la fase 10): [`../examples/complete`](../examples/complete).

- **Lee de SSM:** —
- **Publica en SSM:** lo que publican sus módulos (`identity/tenants/*`, `api/api/*`, `data/dynamodb/tenant-data/*`, `resilience/*`).

Visión general del blueprint, orden de despliegue y objetivos de resiliencia: [`../README.md`](../README.md). Composición entre capas: ADR [0016](../../../docs/adr/0016-blueprint-composition.md).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.30, < 7.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.68.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.1 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_alarms"></a> [alarms](#module\_alarms) | ../../../modules/observability/alarms | n/a |
| <a name="module_api"></a> [api](#module\_api) | ../../../modules/api/apigw-rest | n/a |
| <a name="module_api_function"></a> [api\_function](#module\_api\_function) | ../../../modules/compute/lambda-function | n/a |
| <a name="module_api_waf"></a> [api\_waf](#module\_api\_waf) | ../../../modules/edge/waf-web-acl | n/a |
| <a name="module_backup"></a> [backup](#module\_backup) | ../../../modules/resilience/backup-plan | n/a |
| <a name="module_backup_kms"></a> [backup\_kms](#module\_backup\_kms) | ../../../modules/foundation/kms-key | n/a |
| <a name="module_cdn_logs"></a> [cdn\_logs](#module\_cdn\_logs) | ../../../modules/storage/s3-bucket | n/a |
| <a name="module_dashboard"></a> [dashboard](#module\_dashboard) | ../../../modules/observability/dashboard | n/a |
| <a name="module_edge_alarms"></a> [edge\_alarms](#module\_edge\_alarms) | ../../../modules/observability/alarms | n/a |
| <a name="module_edge_kms"></a> [edge\_kms](#module\_edge\_kms) | ../../../modules/foundation/kms-key | n/a |
| <a name="module_kms"></a> [kms](#module\_kms) | ../../../modules/foundation/kms-key | n/a |
| <a name="module_security_headers"></a> [security\_headers](#module\_security\_headers) | ../../../modules/edge/security-headers | n/a |
| <a name="module_site"></a> [site](#module\_site) | ../../../modules/edge/cloudfront-static-site | n/a |
| <a name="module_table"></a> [table](#module\_table) | ../../../modules/data/dynamodb-table | n/a |
| <a name="module_tenant_role"></a> [tenant\_role](#module\_tenant\_role) | ../../../modules/identity/tenant-access-role | n/a |
| <a name="module_tenants"></a> [tenants](#module\_tenants) | ../../../modules/identity/cognito-user-pool | n/a |
| <a name="module_viewer_certificate"></a> [viewer\_certificate](#module\_viewer\_certificate) | ../../../modules/edge/acm-certificate | n/a |
| <a name="module_waf"></a> [waf](#module\_waf) | ../../../modules/edge/waf-web-acl | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_secretsmanager_secret.origin_verify](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.origin_verify](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [random_password.origin_verify](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alarm_emails"></a> [alarm\_emails](#input\_alarm\_emails) | Correos suscritos a las alarmas (deben confirmar la suscripción). En prod, al menos uno. | `list(string)` | `[]` | no |
| <a name="input_api_function"></a> [api\_function](#input\_api\_function) | Código de la Lambda de la API (debe asumir el rol del tenant con la etiqueta de sesión del JWT y cachear las credenciales por tenant): paquete zip (s3\_bucket + s3\_key, con s3\_object\_version para fijarlo; runtime y handler) o imagen por digest (image\_uri). Lo publica el pipeline de la aplicación. | <pre>object({<br/>    s3_bucket             = optional(string)<br/>    s3_key                = optional(string)<br/>    s3_object_version     = optional(string)<br/>    runtime               = optional(string, "python3.13")<br/>    handler               = optional(string, "app.handler")<br/>    image_uri             = optional(string)<br/>    memory_size           = optional(number, 512)<br/>    timeout_seconds       = optional(number, 10)<br/>    environment_variables = optional(map(string), {})<br/>  })</pre> | n/a | yes |
| <a name="input_auth"></a> [auth](#input\_auth) | Cognito compartido de tenants: callback\_urls/logout\_urls del app client web (vacías = https://<domain\_name>/auth/callback y https://<domain\_name>/), domain\_prefix de managed login (null = sin dominio) y email (en prod, SES con sending\_account = DEVELOPER). El alta de usuarios la hace el onboarding (custom:tenant\_id), no hay registro libre. | <pre>object({<br/>    callback_urls = optional(list(string), [])<br/>    logout_urls   = optional(list(string), [])<br/>    domain_prefix = optional(string)<br/>    email = optional(object({<br/>      sending_account    = optional(string, "COGNITO_DEFAULT")<br/>      source_arn         = optional(string)<br/>      from_email_address = optional(string)<br/>      reply_to           = optional(string)<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_content_security_policy"></a> [content\_security\_policy](#input\_content\_security\_policy) | Content-Security-Policy del sitio (depende del frontend). null = sin la cabecera. | `string` | `null` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Dominio público de la aplicación SaaS (p. ej. app.cliente.com): alias de CloudFront, certificado y URLs de Cognito. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_manage_apigw_account_logging_role"></a> [manage\_apigw\_account\_logging\_role](#input\_manage\_apigw\_account\_logging\_role) | Crea el rol de CloudWatch de API Gateway y lo fija en la cuenta/región (necesario para los logs de la REST API). Es único por cuenta y región: ponlo en false si otra pila de la cuenta ya lo gestiona. | `bool` | `true` | no |
| <a name="input_origin_verify_version"></a> [origin\_verify\_version](#input\_origin\_verify\_version) | Versión del token x-origin-verify entre CloudFront y la API. Súbela para rotarlo: la Lambda acepta el valor actual y el anterior (AWSPREVIOUS) durante la propagación (ADR 0010). | `number` | `1` | no |
| <a name="input_price_class"></a> [price\_class](#input\_price\_class) | Clase de precio de CloudFront. | `string` | `"PriceClass_100"` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto (cliente); prefijo de los nombres de recursos y de las rutas SSM. | `string` | n/a | yes |
| <a name="input_spa_error_codes"></a> [spa\_error\_codes](#input\_spa\_error\_codes) | Errores que se sirven como /index.html con 200. Desaconsejado (por defecto ninguno): el enrutado de la SPA lo hace una CloudFront Function, y esta reescritura convertiría en 200 los bloqueos del WAF y los 403/404 de /api/*. | `list(number)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales para los recursos (las obligatorias van en default\_tags del provider, en live/). | `map(string)` | `{}` | no |
| <a name="input_usage_plans"></a> [usage\_plans](#input\_usage\_plans) | Planes de uso de la REST API por tier (throttling y cuota por API key). El onboarding crea la API key de cada tenant y la asocia al plan de su tier (usage\_plan\_id/<tier> en SSM). | <pre>map(object({<br/>    rate_limit   = number<br/>    burst_limit  = number<br/>    quota_limit  = optional(number)<br/>    quota_period = optional(string, "MONTH")<br/>  }))</pre> | <pre>{<br/>  "basic": {<br/>    "burst_limit": 20,<br/>    "quota_limit": 100000,<br/>    "rate_limit": 10<br/>  },<br/>  "pro": {<br/>    "burst_limit": 100,<br/>    "rate_limit": 50<br/>  }<br/>}</pre> | no |
| <a name="input_viewer_certificate_arn"></a> [viewer\_certificate\_arn](#input\_viewer\_certificate\_arn) | Certificado ACM ya emitido en us-east-1 que cubre domain\_name (DNS fuera de Route 53, runbook external-dns-validation). null = el blueprint lo crea y valida en zone\_id. | `string` | `null` | no |
| <a name="input_waf_mode"></a> [waf\_mode](#input\_waf\_mode) | web\_acl crea el Web ACL de CloudFront con edge/waf-web-acl; flat\_rate no lo crea porque el WAF viene en el plan de precio fijo de CloudFront, que se contrata en la consola (paso manual del runbook). | `string` | `"web_acl"` | no |
| <a name="input_waf_rules_mode"></a> [waf\_rules\_mode](#input\_waf\_rules\_mode) | Acción de las reglas gestionadas de los WAF: block o count. null = count en dev (para probar reglas nuevas) y block en el resto (plan 9.2). | `string` | `null` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Zona de Route 53 del dominio: valida el certificado y crea los alias A/AAAA hacia CloudFront. null = DNS externo (entonces viewer\_certificate\_arn es obligatorio y los registros se crean a mano). | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alarm_topic_arns"></a> [alarm\_topic\_arns](#output\_alarm\_topic\_arns) | Topics SNS de alarmas: regional y de borde (us-east-1). |
| <a name="output_api_function_name"></a> [api\_function\_name](#output\_api\_function\_name) | Nombre de la Lambda de la API. |
| <a name="output_api_invoke_url"></a> [api\_invoke\_url](#output\_api\_invoke\_url) | URL de la etapa (directa: el WAF regional la bloquea sin la cabecera x-origin-verify de CloudFront). |
| <a name="output_backup_vault_name"></a> [backup\_vault\_name](#output\_backup\_vault\_name) | Vault de AWS Backup del entorno. |
| <a name="output_dashboard_name"></a> [dashboard\_name](#output\_dashboard\_name) | Dashboard de CloudWatch del blueprint. |
| <a name="output_distribution_domain_name"></a> [distribution\_domain\_name](#output\_distribution\_domain\_name) | Dominio *.cloudfront.net (destino del CNAME si el DNS es externo). |
| <a name="output_distribution_id"></a> [distribution\_id](#output\_distribution\_id) | ID de la distribución (invalidaciones tras desplegar el frontend). |
| <a name="output_site_bucket_id"></a> [site\_bucket\_id](#output\_site\_bucket\_id) | Bucket donde el pipeline sube el frontend. |
| <a name="output_site_kms_key_arn"></a> [site\_kms\_key\_arn](#output\_site\_kms\_key\_arn) | CMK del bucket del sitio (el pipeline necesita kms:GenerateDataKey sobre ella). |
| <a name="output_table_name"></a> [table\_name](#output\_table\_name) | Tabla pool (clave de partición tenant\_id). |
| <a name="output_tenant_role_arn"></a> [tenant\_role\_arn](#output\_tenant\_role\_arn) | Rol ABAC que la Lambda asume con la etiqueta de sesión del tenant. |
| <a name="output_usage_plan_ids"></a> [usage\_plan\_ids](#output\_usage\_plan\_ids) | Planes de uso por tier: el onboarding asocia la API key del tenant al de su tier. |
| <a name="output_user_pool_client_ids"></a> [user\_pool\_client\_ids](#output\_user\_pool\_client\_ids) | IDs de los app clients. |
| <a name="output_user_pool_id"></a> [user\_pool\_id](#output\_user\_pool\_id) | ID del user pool compartido de tenants. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- El WAF regional de la etapa bloquea cualquier petición sin el `x-origin-verify` de CloudFront (ADR 0010) y aplica las reglas gestionadas; CloudFront tiene su propio WAF (o el plan flat-rate).
- Aislamiento pool (ADR 0006): `tenant_id` es la clave de partición y el rol solo admite `dynamodb:LeadingKeys` = etiqueta de sesión del tenant; `Deny` sin etiqueta.
- Autorizador `COGNITO_USER_POOLS` + API key por tenant (planes de uso); `custom:tenant_id` solo lo asigna el onboarding.
- `endpoint_access_mode = STRICT` y TLS 1.3/1.2 en la API.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
