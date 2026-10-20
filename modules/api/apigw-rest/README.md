# api/apigw-rest

**REST API de API Gateway** (SaaS T3) regional, detrás de CloudFront: integración Lambda proxy en `/` y `/{proxy+}`, **autorizador de Cognito** en todos los métodos, **API keys + planes de uso por tier** (throttling y cuota por tenant, que HTTP API no tiene), **WAF regional** con verificación de origen (obligatorio en prod), política TLS 1.3/1.2 con acceso **STRICT**, preflight CORS sin autorización, logs de acceso y ejecución cifrados con la CMK y, opcionalmente, el rol de CloudWatch de API Gateway de la cuenta. Fase 8.5.

## Uso

```hcl
module "api" {
  source = "../../modules/api/apigw-rest"

  project                = "acme"
  environment            = "prod"
  kms_key_arn            = module.kms.key_arn # service_principals = ["logs.<región>.amazonaws.com"]
  lambda_function_arn    = module.api_backend.function_arn
  cognito_user_pool_arns = [module.tenants.user_pool_arn]

  usage_plans = {
    basic = { rate_limit = 10, burst_limit = 20, quota_limit = 100000 }
    pro   = { rate_limit = 100, burst_limit = 200 }
  }

  web_acl_arn       = module.waf_regional.web_acl_arn # edge/waf-web-acl con scope REGIONAL y origin_verify
  cors_allow_origin = "https://app.acme.com"

  manage_account_logging_role = true # en UNA sola instancia por cuenta y región
}
```

En `edge/cloudfront-static-site`, el origen `/api/*` usa `origin_domain_name` y `origin_path` (`/v1`), `AllViewerExceptHostHeader` y la cabecera `x-origin-verify`; la Lambda recibe la ruta completa (`/api/...`).

### Onboarding de un tenant (fuera de OpenTofu)

Cada tenant tiene su API key, asociada al plan de su tier; el valor de la clave nunca entra en el estado ni en SSM:

```bash
KEY_ID=$(aws apigateway create-api-key --name "tenant-$TENANT_ID" --enabled --tags tenant=$TENANT_ID --query id --output text)
aws apigateway create-usage-plan-key --usage-plan-id "$(aws ssm get-parameter --name /acme/prod/api/api/usage_plan_id/pro --query Parameter.Value --output text)" \
  --key-type API_KEY --key-id "$KEY_ID"
# Entregar el valor al tenant por un canal seguro (aws apigateway get-api-key --include-value).
```

La API key **no autentica**: identifica al tenant para el throttling y la cuota. La identidad sale del token de Cognito, y la aplicación debe comprobar que el tenant del token (`custom:tenant_id`) coincide con el de la API key (`requestContext.identity.apiKeyId` → tenant).

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

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_api_gateway_account.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_account) | resource |
| [aws_api_gateway_authorizer.cognito](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_authorizer) | resource |
| [aws_api_gateway_deployment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_deployment) | resource |
| [aws_api_gateway_gateway_response.cors](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_gateway_response) | resource |
| [aws_api_gateway_integration.any](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration) | resource |
| [aws_api_gateway_integration.options](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration) | resource |
| [aws_api_gateway_integration_response.options](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration_response) | resource |
| [aws_api_gateway_method.any](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method) | resource |
| [aws_api_gateway_method.options](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method) | resource |
| [aws_api_gateway_method_response.options](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method_response) | resource |
| [aws_api_gateway_method_settings.all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method_settings) | resource |
| [aws_api_gateway_resource.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_rest_api.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_rest_api) | resource |
| [aws_api_gateway_stage.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_stage) | resource |
| [aws_api_gateway_usage_plan.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_usage_plan) | resource |
| [aws_cloudwatch_log_group.access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.account_logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.account_logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_permission.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_ssm_parameter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_wafv2_web_acl_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.account_logging_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_api_key_required"></a> [api\_key\_required](#input\_api\_key\_required) | Exige API key (cabecera x-api-key) además del token: necesario para aplicar los planes de uso por tenant o tier. Las API keys las crea el onboarding de cada tenant (no OpenTofu) y las asocia al plan de su tier. | `bool` | `true` | no |
| <a name="input_authorization_scopes"></a> [authorization\_scopes](#input\_authorization\_scopes) | Scopes OAuth exigidos en todos los métodos (salvo OPTIONS). Con scopes, el autorizador exige access tokens en lugar de ID tokens. Vacío = ID token. | `list(string)` | `[]` | no |
| <a name="input_cognito_user_pool_arns"></a> [cognito\_user\_pool\_arns](#input\_cognito\_user\_pool\_arns) | ARNs de los user pools cuyos tokens acepta el autorizador COGNITO\_USER\_POOLS (uno por tier o por tenant en SaaS T1). Valida firma, emisor y caducidad del ID token (o del access token si hay authorization\_scopes); no valida claims personalizados. | `list(string)` | n/a | yes |
| <a name="input_cors_allow_origin"></a> [cors\_allow\_origin](#input\_cors\_allow\_origin) | Origen exacto del frontend para CORS (https://app.ejemplo.com). Crea métodos OPTIONS sin autorización para el preflight y añade la cabecera a las respuestas de error de API Gateway; las respuestas de la Lambda deben incluir sus propias cabeceras CORS. null = sin CORS (llamadas a través de CloudFront en el mismo dominio). | `string` | `null` | no |
| <a name="input_endpoint_access_mode"></a> [endpoint\_access\_mode](#input\_endpoint\_access\_mode) | STRICT (por defecto): API Gateway exige que el SNI y la cabecera Host coincidan con el endpoint (cierra el domain fronting); CloudFront cumple porque llega por el nombre execute-api. BASIC solo para migraciones. El cambio de BASIC a STRICT tarda unos 15 minutos en aplicarse. | `string` | `"STRICT"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_integration_timeout_milliseconds"></a> [integration\_timeout\_milliseconds](#input\_integration\_timeout\_milliseconds) | Timeout de la integración, en milisegundos (50-29000). | `number` | `29000` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN de la CMK del entorno que cifra los log groups de acceso y ejecución. Su política debe autorizar al principal logs.<región>.amazonaws.com. | `string` | n/a | yes |
| <a name="input_lambda_function_arn"></a> [lambda\_function\_arn](#input\_lambda\_function\_arn) | ARN de la función Lambda que atiende la API (integración proxy en / y /{proxy+}; la función enruta por método y ruta). El módulo concede a esta etapa el permiso para invocarla. | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retención de los log groups, en días. En prod, al menos 90. | `number` | `90` | no |
| <a name="input_logging_level"></a> [logging\_level](#input\_logging\_level) | Logs de ejecución de API Gateway: OFF, ERROR (por defecto) o INFO. Nunca se registran cuerpos (data\_trace desactivado). Requieren el rol de CloudWatch de la cuenta (manage\_account\_logging\_role en una instancia por cuenta y región). | `string` | `"ERROR"` | no |
| <a name="input_manage_account_logging_role"></a> [manage\_account\_logging\_role](#input\_manage\_account\_logging\_role) | Crea el rol que API Gateway usa para escribir en CloudWatch Logs y lo fija en la configuración de la cuenta (aws\_api\_gateway\_account). Es un ajuste único por cuenta y región, necesario para los logs de acceso y de ejecución de cualquier REST API: actívalo en UNA sola instancia. | `bool` | `false` | no |
| <a name="input_minimum_compression_size"></a> [minimum\_compression\_size](#input\_minimum\_compression\_size) | Tamaño mínimo de respuesta, en bytes, para comprimirla (0-10485760). null = sin compresión. | `number` | `1024` | no |
| <a name="input_name"></a> [name](#input\_name) | Nombre lógico de la API; el nombre real es <project>-<environment>-<name>. | `string` | `"api"` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_publish_ssm_parameters"></a> [publish\_ssm\_parameters](#input\_publish\_ssm\_parameters) | Publica en SSM Parameter Store, bajo /<project>/<env>/api/<name>/, el ID de la API, la URL de la etapa y los IDs de los planes de uso (los necesita el onboarding para asociar las API keys). | `bool` | `true` | no |
| <a name="input_security_policy"></a> [security\_policy](#input\_security\_policy) | Política TLS del endpoint execute-api. Las políticas SecurityPolicy\_* (mejoradas) exigen endpoint\_access\_mode. Por defecto TLS 1.3 con 1.2 de respaldo. | `string` | `"SecurityPolicy_TLS13_1_2_2021_06"` | no |
| <a name="input_stage_name"></a> [stage\_name](#input\_stage\_name) | Nombre de la etapa; es el origin\_path del origen /api/* en CloudFront. | `string` | `"v1"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_throttling"></a> [throttling](#input\_throttling) | Throttling de la etapa para todos los métodos (burst\_limit, rate\_limit por segundo). Los planes de uso limitan además por API key. | <pre>object({<br/>    burst_limit = optional(number, 100)<br/>    rate_limit  = optional(number, 50)<br/>  })</pre> | `{}` | no |
| <a name="input_usage_plans"></a> [usage\_plans](#input\_usage\_plans) | Planes de uso por tier (p. ej. basic, pro) con throttling (rate\_limit por segundo, burst\_limit) y cuota opcional (quota\_limit peticiones por quota\_period: DAY, WEEK o MONTH). Con api\_key\_required debe haber al menos uno. | <pre>map(object({<br/>    rate_limit   = number<br/>    burst_limit  = number<br/>    quota_limit  = optional(number)<br/>    quota_period = optional(string, "MONTH")<br/>    description  = optional(string, "")<br/>  }))</pre> | `{}` | no |
| <a name="input_web_acl_arn"></a> [web\_acl\_arn](#input\_web\_acl\_arn) | ARN de un Web ACL REGIONAL (edge/waf-web-acl con origin\_verify) que se asocia a la etapa: bloquea las peticiones que no lleguen por CloudFront con la cabecera x-origin-verify. Obligatorio en prod. | `string` | `null` | no |
| <a name="input_web_acl_enabled"></a> [web\_acl\_enabled](#input\_web\_acl\_enabled) | Asocia web\_acl\_arn a la etapa. Indícalo (true) cuando el Web ACL se crea en el mismo apply: OpenTofu necesita conocer al planificar si se crea la asociación. null = asociar si web\_acl\_arn no es null. | `bool` | `null` | no |
| <a name="input_xray_tracing_enabled"></a> [xray\_tracing\_enabled](#input\_xray\_tracing\_enabled) | Trazas de X-Ray en API Gateway. false por defecto: la aplicación usa OpenTelemetry de extremo a extremo y activar ambas duplica trazas (ADR 0008). | `bool` | `false` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_access_log_group_name"></a> [access\_log\_group\_name](#output\_access\_log\_group\_name) | Log group de los logs de acceso. |
| <a name="output_authorizer_id"></a> [authorizer\_id](#output\_authorizer\_id) | ID del autorizador de Cognito. |
| <a name="output_execution_arn"></a> [execution\_arn](#output\_execution\_arn) | ARN de ejecución de la API. |
| <a name="output_invoke_url"></a> [invoke\_url](#output\_invoke\_url) | URL de la etapa (https://<id>.execute-api.<región>.amazonaws.com/<etapa>). |
| <a name="output_origin_domain_name"></a> [origin\_domain\_name](#output\_origin\_domain\_name) | Dominio para el origen /api/* de edge/cloudfront-static-site (con AllViewerExceptHostHeader y endpoint\_access\_mode STRICT). |
| <a name="output_origin_path"></a> [origin\_path](#output\_origin\_path) | origin\_path del origen de CloudFront (/<etapa>). |
| <a name="output_rest_api_id"></a> [rest\_api\_id](#output\_rest\_api\_id) | ID de la REST API. |
| <a name="output_stage_arn"></a> [stage\_arn](#output\_stage\_arn) | ARN de la etapa (recurso al que se asocia el WAF regional). |
| <a name="output_stage_name"></a> [stage\_name](#output\_stage\_name) | Nombre de la etapa. |
| <a name="output_usage_plan_ids"></a> [usage\_plan\_ids](#output\_usage\_plan\_ids) | ID de cada plan de uso por tier: el onboarding asocia la API key del tenant al plan de su tier (aws apigateway create-usage-plan-key). |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Token en todos los métodos** (`COGNITO_USER_POOLS`, cabecera `Authorization`): valida firma, emisor y caducidad del **ID token** o, con `authorization_scopes`, del **access token**. No valida claims personalizados: el tenant lo lee la aplicación del contexto del autorizador (ADR 0006).
- **API key obligatoria por defecto** + planes de uso por tier (throttling y cuota por tenant). Sin planes de uso no se admite `api_key_required` (ninguna clave funcionaría). Las claves las crea el onboarding, no OpenTofu, para que su valor no acabe en el estado.
- **Verificación de origen en el WAF regional** (`web_acl_arn`, obligatorio en prod): `edge/waf-web-acl` con `origin_verify` bloquea lo que no llegue por CloudFront con la cabecera `x-origin-verify` (ADR 0010); añade además las reglas gestionadas y los límites de tasa. Aceptación del paso 7 de la fase 8 en `tests/integration.tftest.hcl`.
- **TLS del endpoint execute-api:** `SecurityPolicy_TLS13_1_2_2021_06` (TLS 1.3 con 1.2 de respaldo) y `endpoint_access_mode = "STRICT"`, que exige que el SNI y la cabecera `Host` coincidan con el endpoint y cierra el *domain fronting*. CloudFront cumple porque llega por el nombre `execute-api` (`AllViewerExceptHostHeader`). El paso de `BASIC` a `STRICT` tarda unos 15 minutos.
- **Preflight CORS** (`cors_allow_origin`, origen exacto): métodos `OPTIONS` sin autorizador ni API key que responden con `MOCK` (no invocan la Lambda ni devuelven datos), y cabeceras CORS en las respuestas de error de API Gateway (`DEFAULT_4XX`/`DEFAULT_5XX`), para que el navegador no oculte un 401/403/429 tras un error de CORS. Las respuestas de la Lambda llevan sus propias cabeceras.
- **Sin caché de etapa:** las respuestas dependen del tenant y del token; una caché compartida podría servir datos de otro tenant. Sin certificado de cliente: el origen se protege con la cabecera y el WAF.
- **Logs:** de acceso en JSON (sin cabeceras, cuerpos ni el valor de la API key; incluyen `apiKeyId`, `usagePlanId` y el estado de WAF) y de ejecución en `ERROR` por defecto, **sin `data_trace`** (registraría cuerpos con datos personales). El log group de ejecución (`API-Gateway-Execution-Logs_<id>/<etapa>`) lo crea el módulo antes que API Gateway, con la CMK y retención. Ambos necesitan el **rol de CloudWatch de la cuenta**, que es único por cuenta y región: `manage_account_logging_role = true` en una sola instancia (rol con `aws:SourceAccount` y la política gestionada `AmazonAPIGatewayPushToCloudWatchLogs`, excepción al ADR 0012 porque escribe en los log groups de cualquier API).
- **X-Ray desactivado por defecto** (ADR 0008: OpenTelemetry de extremo a extremo; activar ambos duplica trazas).
- **Permiso de invocación** de la Lambda limitado a la etapa de esta API (`<execution_arn>/<etapa>/*/*`) y a la cuenta. Timeout de integración de 29 s como máximo.
- **Despliegues** con `triggers` sobre la definición de la API y `create_before_destroy` (sin cortes al cambiar métodos).
- **SSM** (`/<project>/<env>/api/<name>/…`): `rest_api_id`, `invoke_url` y `usage_plan_id/<tier>` (los usa el onboarding); nunca API keys.

### Cómo se verificó

- 20 tests unitarios con `mock_provider`: endpoint regional con TLS 1.3/1.2 y STRICT, token y API key en todos los métodos, autorizador, recurso proxy, integración y permiso de Lambda, etapa sin X-Ray con logs JSON y estado de WAF, ajustes de métodos (sin `data_trace` ni caché), log group de ejecución previo, planes por tier, SSM, asociación del WAF, CORS (preflight MOCK sin autorización y respuestas de error), scopes, rol de CloudWatch de la cuenta, logs desactivables, origen para CloudFront y 8 validaciones que deben fallar.
- **Plan real offline** contra el provider 6.67.0 (credenciales falsas; la cuenta sustituida por una constante) con todas las opciones: 33 recursos aceptados, incluidos `security_policy`/`endpoint_access_mode` y la asociación de WAF a la etapa.
- **Pendiente en sandbox** (WAF regional ~5 USD/mes prorrateado por hora): `tests/integration.tftest.hcl`, que comprueba con peticiones reales que una llamada directa sin `x-origin-verify` recibe 403 del WAF y con la cabecera pero sin token, 401; y que `STRICT` acepta el tráfico de CloudFront (prueba E2E de la fase 12).

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
