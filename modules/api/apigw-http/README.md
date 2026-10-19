# api/apigw-http

**HTTP API de API Gateway** (E-commerce T3) con integraciones Lambda proxy (payload 2.0), **autorizador JWT** (Cognito u otro proveedor OIDC) en todas las rutas salvo las declaradas públicas, scopes por ruta, CORS restringido, throttling por defecto y por ruta, y logs de acceso JSON cifrados con la CMK. Se publica detrás de CloudFront (`edge/cloudfront-static-site`, origen `/api/*`). Fase 8.5.

## Uso

```hcl
module "api" {
  source = "../../modules/api/apigw-http"

  project     = "acme"
  environment = "prod"
  kms_key_arn = module.kms.key_arn # service_principals = ["logs.<región>.amazonaws.com"]

  integrations = {
    orders = { lambda_function_arn = module.orders.function_arn }
  }

  routes = {
    "GET /products"  = { integration = "orders", authorization = "NONE" }
    "GET /orders"    = { integration = "orders" }
    "POST /orders"   = { integration = "orders", throttling_rate_limit = 10, throttling_burst_limit = 20 }
  }

  jwt_authorizer = {
    issuer   = module.customers.issuer_url
    audience = values(module.customers.client_ids)
  }

  cors = { allow_origins = ["https://shop.acme.com"] }
}
```

### Verificación del origen en la Lambda (HTTP API no admite WAF ni resource policies)

CloudFront añade la cabecera `x-origin-verify` con un token rotado (ADR 0010); como el endpoint `execute-api` es público, la función rechaza lo que no la lleve. El token se lee de Secrets Manager al arrancar y se aceptan el actual y el anterior durante la rotación:

```python
import hmac, json, os, boto3

_tokens = None

def _valid_tokens():
    global _tokens
    if _tokens is None:
        sm = boto3.client("secretsmanager")
        arn = os.environ["ORIGIN_VERIFY_SECRET_ARN"]
        _tokens = [sm.get_secret_value(SecretId=arn, VersionStage=s)["SecretString"]
                   for s in ("AWSCURRENT", "AWSPREVIOUS") if _has_stage(sm, arn, s)]
    return _tokens

def _has_stage(sm, arn, stage):
    return any(stage in v for v in sm.describe_secret(SecretId=arn)["VersionIdsToStages"].values())

def handler(event, context):
    got = (event.get("headers") or {}).get("x-origin-verify", "")
    if not any(hmac.compare_digest(got, t) for t in _valid_tokens()):
        return {"statusCode": 403, "body": json.dumps({"message": "Forbidden"})}
    tenant = event["requestContext"].get("authorizer", {}).get("jwt", {}).get("claims", {}).get("tenant_id")
    ...
```

Riesgo residual: hasta que la Lambda rechaza la petición, la invocación se produce (y se cobra). La REST API de SaaS T3 sí lo corta en el WAF regional (`api/apigw-rest`).

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
| [aws_apigatewayv2_api.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api) | resource |
| [aws_apigatewayv2_authorizer.jwt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_authorizer) | resource |
| [aws_apigatewayv2_integration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration) | resource |
| [aws_apigatewayv2_route.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route) | resource |
| [aws_apigatewayv2_stage.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_stage) | resource |
| [aws_cloudwatch_log_group.access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_lambda_permission.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_ssm_parameter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cors"></a> [cors](#input\_cors) | CORS restringido a los orígenes del frontend (sin comodines). API Gateway responde a las peticiones preflight. null = sin CORS (la API solo se llama a través de CloudFront en el mismo dominio). | <pre>object({<br/>    allow_origins     = list(string)<br/>    allow_methods     = optional(list(string), ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"])<br/>    allow_headers     = optional(list(string), ["authorization", "content-type"])<br/>    expose_headers    = optional(list(string), [])<br/>    max_age_seconds   = optional(number, 300)<br/>    allow_credentials = optional(bool, false)<br/>  })</pre> | `null` | no |
| <a name="input_disable_execute_api_endpoint"></a> [disable\_execute\_api\_endpoint](#input\_disable\_execute\_api\_endpoint) | Desactiva el endpoint por defecto execute-api. Déjalo en false si el origen de CloudFront es ese endpoint (patrón de los blueprints T3); actívalo solo con un dominio propio de API Gateway. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_integrations"></a> [integrations](#input\_integrations) | Integraciones Lambda proxy (formato de payload 2.0) por clave estable: lambda\_function\_arn y timeout\_milliseconds (50-30000; el máximo de HTTP API es 30 s). El módulo concede a esta API el permiso para invocar cada función. | <pre>map(object({<br/>    lambda_function_arn  = string<br/>    timeout_milliseconds = optional(number, 29000)<br/>  }))</pre> | n/a | yes |
| <a name="input_jwt_authorizer"></a> [jwt\_authorizer](#input\_jwt\_authorizer) | Autorizador JWT (Cognito u otro proveedor OIDC): issuer (p. ej. issuer\_url de identity/cognito-user-pool) y audience (IDs de los app clients). Valida firma, emisor, audiencia y caducidad; NO valida claims personalizados como el tenant, que lee la aplicación. | <pre>object({<br/>    issuer   = string<br/>    audience = list(string)<br/>  })</pre> | `null` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN de la CMK del entorno que cifra el log group de acceso. Su política debe autorizar al principal logs.<región>.amazonaws.com. | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retención del log group de acceso, en días. En prod, al menos 90. | `number` | `90` | no |
| <a name="input_name"></a> [name](#input\_name) | Nombre lógico de la API; el nombre real es <project>-<environment>-<name>. | `string` | `"api"` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_publish_ssm_parameters"></a> [publish\_ssm\_parameters](#input\_publish\_ssm\_parameters) | Publica en SSM Parameter Store, bajo /<project>/<env>/api/<name>/, el ID y el endpoint de la API (origen de CloudFront en la capa de borde). | `bool` | `true` | no |
| <a name="input_routes"></a> [routes](#input\_routes) | Rutas por route key ("GET /orders", "POST /orders/{id}" o "$default"): integration (clave de integrations), authorization (JWT por defecto o NONE para rutas públicas, como un catálogo), scopes OAuth exigidos (solo con JWT; requieren access token) y límites de throttling propios de la ruta. | <pre>map(object({<br/>    integration            = string<br/>    authorization          = optional(string, "JWT")<br/>    scopes                 = optional(list(string), [])<br/>    throttling_burst_limit = optional(number)<br/>    throttling_rate_limit  = optional(number)<br/>  }))</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_throttling"></a> [throttling](#input\_throttling) | Límites por defecto de la API (todas las rutas): burst\_limit (peticiones simultáneas) y rate\_limit (peticiones por segundo). Las rutas pueden ajustarlos. | <pre>object({<br/>    burst_limit = optional(number, 100)<br/>    rate_limit  = optional(number, 50)<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_access_log_group_name"></a> [access\_log\_group\_name](#output\_access\_log\_group\_name) | Log group de los logs de acceso. |
| <a name="output_api_endpoint"></a> [api\_endpoint](#output\_api\_endpoint) | Endpoint por defecto (https://<id>.execute-api.<región>.amazonaws.com). |
| <a name="output_api_id"></a> [api\_id](#output\_api\_id) | ID de la HTTP API. |
| <a name="output_authorizer_id"></a> [authorizer\_id](#output\_authorizer\_id) | ID del autorizador JWT; null si no hay. |
| <a name="output_execution_arn"></a> [execution\_arn](#output\_execution\_arn) | ARN de ejecución (base de las condiciones source\_arn de los permisos de Lambda). |
| <a name="output_origin_domain_name"></a> [origin\_domain\_name](#output\_origin\_domain\_name) | Dominio para el origen /api/* de edge/cloudfront-static-site (con AllViewerExceptHostHeader: el endpoint tiene certificado de AWS para su propio nombre). |
| <a name="output_stage_name"></a> [stage\_name](#output\_stage\_name) | Nombre de la etapa ($default, desplegada automáticamente). |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **JWT por defecto:** toda ruta sin `authorization = "NONE"` usa el autorizador JWT (cabecera `Authorization`), que valida firma, emisor (`issuer`), audiencia (IDs de los app clients) y caducidad. Las rutas JWT exigen un autorizador (validado). Las **scopes** por ruta solo se admiten con JWT y exigen *access tokens*. El autorizador **no** valida claims personalizados: el tenant (`tenant_id` del trigger *pre token generation* o `custom:tenant_id` del ID token) lo lee la aplicación de `requestContext.authorizer.jwt.claims` y es la única fuente del tenant (ADR 0006).
- **Rutas públicas explícitas** (`authorization = "NONE"`, p. ej. catálogo o salud): sin scopes y con su propio throttling si hace falta.
- **CORS** solo con orígenes exactos `https://` (o `http://localhost` fuera de prod), sin comodines ni credenciales por defecto; API Gateway responde a las peticiones preflight. Si la API solo se llama a través de CloudFront en el mismo dominio, deja `cors = null`.
- **Throttling** por defecto en toda la API (100 de ráfaga, 50/s) y por ruta (`route_settings` solo para las rutas que lo declaran). HTTP API no tiene planes de uso por cliente: si hacen falta, `api/apigw-rest`.
- **Logs de acceso** en JSON a un log group propio con la CMK y retención (≥ 90 días en prod), **sin cabeceras ni cuerpos** (pueden contener tokens o datos personales); incluyen errores del autorizador y de la integración. HTTP API escribe con su rol vinculado al servicio: no necesita el rol de CloudWatch de la cuenta.
- **Permisos de invocación** de cada función limitados al ARN de ejecución de esta API (`<execution_arn>/*/*`) y a la cuenta (`source_account`); un `statement_id` por integración.
- **Timeout** de integración de 29 s por defecto (máximo de HTTP API: 30 s, no ampliable).
- **Endpoint execute-api activo** por defecto: es el origen de CloudFront en los blueprints T3 (con `AllViewerExceptHostHeader`, ya que el endpoint tiene certificado de AWS para su propio nombre). Protegido por la cabecera de origen en la Lambda (arriba).
- **SSM** (`/<project>/<env>/api/<name>/…`): `api_id`, `api_endpoint`, `execution_arn`.

### Cómo se verificó

- 20 tests unitarios con `mock_provider`: API HTTP con endpoint activo y sin CORS por defecto, integraciones proxy 2.0 con su timeout, rutas JWT/públicas y scopes, autorizador (emisor, audiencia, cabecera), etapa `$default` con throttling global y por ruta, formato de logs JSON sin cabeceras ni cuerpos, log group cifrado, permisos de Lambda acotados, CORS restringido, SSM, dominio de origen para CloudFront y 11 validaciones que deben fallar.
- **Plan real offline** contra el provider 6.67.0 (credenciales falsas; la cuenta del permiso sustituida por una constante) con rutas JWT, con scopes, con throttling propio y `$default` pública: 13 recursos aceptados.
- **Pendiente en sandbox** (sin coste fijo): `tests/integration.tftest.hcl`, que además comprueba con peticiones reales que una ruta JWT sin token devuelve 401 y una pública 200.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
