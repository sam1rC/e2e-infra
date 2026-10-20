# identity/cognito-user-pool

**User pool de Amazon Cognito** con defaults seguros: MFA TOTP (obligatoria en prod), contraseñas largas con historial, correo como usuario y verificado antes de cambiarlo, protección contra borrado fuera de dev, app clients **públicos** (sin secreto, authorization code + PKCE, solo SRP, revocación y rotación de refresh tokens), managed login versión 2 con dominio propio o prefijo, atributo `custom:tenant_id` **inmutable**, threat protection (plan PLUS) y logs cifrados con la CMK. Fase 8.1; en SaaS T1 el blueprint lo instancia por tier o por tenant (`pool_strategy`) con claves estables.

## Uso

```hcl
module "tenants" {
  source = "../../modules/identity/cognito-user-pool"

  project     = "acme"
  environment = "prod"
  name        = "tenants"
  kms_key_arn = module.kms.key_arn # service_principals = ["logs.<región>.amazonaws.com"]

  feature_plan        = "PLUS"
  tenant_id_attribute = true

  email = {
    sending_account    = "DEVELOPER"
    source_arn         = "arn:aws:ses:us-east-1:111122223333:identity/acme.com"
    from_email_address = "no-reply@acme.com"
  }

  app_clients = {
    web = { callback_urls = ["https://app.acme.com/callback"], logout_urls = ["https://app.acme.com/"] }
  }

  domain = {
    custom_domain   = "auth.acme.com"
    certificate_arn = module.acm_us_east_1.certificate_arn
  }

  pre_token_generation_lambda_arn = module.pre_token.function_arn
}
```

Más opciones en [`examples/complete`](examples/complete) (pool PLUS de tenants con trigger y managed login) y [`examples/minimal`](examples/minimal) (pool de clientes de una tienda con registro libre).

### `tenant_id` en el access token (trigger *pre token generation* V2_0)

Los atributos personalizados viajan en el **ID token**, no en el access token. Si la API valida access tokens (necesario para usar scopes), el trigger copia el tenant como claim `tenant_id`; si no, la API debe validar el ID token. El código del ejemplo:

```python
def handler(event, context):
    tenant = event["request"]["userAttributes"].get("custom:tenant_id")
    if tenant:
        claims = {"claimsToAddOrOverride": {"tenant_id": tenant}}
        event["response"]["claimsAndScopeOverrideDetails"] = {
            "accessTokenGeneration": claims,
            "idTokenGeneration": claims,
        }
    return event
```

El JWT authorizer de HTTP API y el autorizador `COGNITO_USER_POOLS` de REST API validan firma, emisor, audiencia y caducidad, **no** los claims personalizados: la aplicación lee `tenant_id` del contexto del autorizador y lo usa para la etiqueta de sesión de `identity/tenant-access-role` (ADR 0006).

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
| [aws_cloudwatch_log_group.auth_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.notifications](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cognito_log_delivery_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_log_delivery_configuration) | resource |
| [aws_cognito_managed_login_branding.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_managed_login_branding) | resource |
| [aws_cognito_risk_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_risk_configuration) | resource |
| [aws_cognito_user_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_group) | resource |
| [aws_cognito_user_pool.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool) | resource |
| [aws_cognito_user_pool_client.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client) | resource |
| [aws_cognito_user_pool_domain.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_domain) | resource |
| [aws_lambda_permission.pre_token_generation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_ssm_parameter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_app_clients"></a> [app\_clients](#input\_app\_clients) | App clients públicos (SPA o móvil) por clave estable: sin secreto, OAuth authorization code con PKCE, solo SRP para la autenticación directa, revocación de tokens y rotación de refresh tokens. Los tokens de acceso e ID duran 15-60 minutos. write\_attributes nunca puede incluir custom:tenant\_id. Los clientes confidenciales no se crean aquí: su secreto quedaría en el estado (regla 0.1). | <pre>map(object({<br/>    callback_urls                 = list(string)<br/>    logout_urls                   = optional(list(string), [])<br/>    oauth_scopes                  = optional(list(string), ["openid", "email", "profile"])<br/>    access_token_validity_minutes = optional(number, 60)<br/>    id_token_validity_minutes     = optional(number, 60)<br/>    refresh_token_validity_days   = optional(number, 30)<br/>    refresh_token_rotation        = optional(bool, true)<br/>    read_attributes               = optional(list(string))<br/>    write_attributes              = optional(list(string), ["email", "name"])<br/>  }))</pre> | `{}` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Protección contra borrado del pool (borrarlo elimina a todos los usuarios). null = activa fuera de dev. En prod no se puede desactivar. | `bool` | `null` | no |
| <a name="input_domain"></a> [domain](#input\_domain) | Dominio de managed login (versión 2): prefix (https://<prefix>.auth.<región>.amazoncognito.com) o custom\_domain + certificate\_arn (certificado ACM en us-east-1). null = sin dominio (solo autenticación directa con SRP). | <pre>object({<br/>    prefix          = optional(string)<br/>    custom_domain   = optional(string)<br/>    certificate_arn = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_email"></a> [email](#input\_email) | Envío de correos (verificación, invitaciones, recuperación). COGNITO\_DEFAULT está limitado a unos 50 correos al día: en prod usa DEVELOPER con una identidad SES verificada (source\_arn) y from\_email\_address. | <pre>object({<br/>    sending_account    = optional(string, "COGNITO_DEFAULT")<br/>    source_arn         = optional(string)<br/>    from_email_address = optional(string)<br/>    reply_to           = optional(string)<br/>    configuration_set  = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_feature_plan"></a> [feature\_plan](#input\_feature\_plan) | Plan de funcionalidades de Cognito (user\_pool\_tier): LITE, ESSENTIALS (por defecto; incluye managed login, pre token generation v2 para personalizar el access token e historial de contraseñas) o PLUS (añade threat protection: credenciales comprometidas, autenticación adaptativa y logs de actividad; SaaS T1). Bajar de PLUS exige desactivar antes la threat protection. | `string` | `"ESSENTIALS"` | no |
| <a name="input_groups"></a> [groups](#input\_groups) | Grupos del pool por nombre estable (p. ej. admins). precedence: menor valor = mayor prioridad cuando un usuario está en varios grupos. | <pre>map(object({<br/>    description = optional(string, "")<br/>    precedence  = optional(number)<br/>  }))</pre> | `{}` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN de la CMK del entorno que cifra los log groups de Cognito. Su política debe autorizar al principal logs.<región>.amazonaws.com. | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retención de los log groups (errores de envío de mensajes y, en PLUS, actividad de usuarios), en días. En prod, al menos 90. | `number` | `365` | no |
| <a name="input_mfa_configuration"></a> [mfa\_configuration](#input\_mfa\_configuration) | MFA del pool (afecta a todos los usuarios: Cognito no admite MFA por grupo): ON, OPTIONAL u OFF. null = ON en prod y OPTIONAL en el resto. El único factor configurado es TOTP. En prod OFF no se admite y OPTIONAL solo con feature\_plan = PLUS y threat protection ENFORCED (MFA adaptativa por riesgo). Si los administradores necesitan MFA obligatoria y los usuarios finales no, usa un pool aparte para administradores. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Nombre lógico del user pool (p. ej. customers, tenants, tier-pro); el nombre real es <project>-<environment>-<name>. En SaaS T1 el blueprint instancia el módulo por tier o por tenant (pool\_strategy) con claves estables. | `string` | n/a | yes |
| <a name="input_password_policy"></a> [password\_policy](#input\_password\_policy) | Política de contraseñas. minimum\_length al menos 12; password\_history\_size (0-24) solo se aplica en ESSENTIALS y PLUS. | <pre>object({<br/>    minimum_length                   = optional(number, 14)<br/>    require_lowercase                = optional(bool, true)<br/>    require_uppercase                = optional(bool, true)<br/>    require_numbers                  = optional(bool, true)<br/>    require_symbols                  = optional(bool, true)<br/>    temporary_password_validity_days = optional(number, 3)<br/>    password_history_size            = optional(number, 5)<br/>  })</pre> | `{}` | no |
| <a name="input_pre_token_generation_enabled"></a> [pre\_token\_generation\_enabled](#input\_pre\_token\_generation\_enabled) | Activa el trigger pre token generation. Indícalo (true) cuando la Lambda se crea en el mismo apply: OpenTofu necesita conocer al planificar si se crea el permiso de invocación. null = activado si pre\_token\_generation\_lambda\_arn no es null. | `bool` | `null` | no |
| <a name="input_pre_token_generation_lambda_arn"></a> [pre\_token\_generation\_lambda\_arn](#input\_pre\_token\_generation\_lambda\_arn) | ARN de la Lambda del trigger pre token generation (versión V2\_0), p. ej. para copiar custom:tenant\_id al access token. Requiere ESSENTIALS o PLUS. El módulo concede a Cognito el permiso para invocarla. null = sin trigger. | `string` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_publish_ssm_parameters"></a> [publish\_ssm\_parameters](#input\_publish\_ssm\_parameters) | Publica en SSM Parameter Store, bajo /<project>/<env>/identity/<name>/, el ID y ARN del pool, el emisor (issuer) y los IDs de los app clients, para las capas que validan los JWT. | `bool` | `true` | no |
| <a name="input_self_registration_enabled"></a> [self\_registration\_enabled](#input\_self\_registration\_enabled) | Permite que los usuarios se registren solos (tienda online). false = solo el backend crea usuarios (onboarding SaaS, que asigna custom:tenant\_id con credenciales de administrador). | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_tenant_id_attribute"></a> [tenant\_id\_attribute](#input\_tenant\_id\_attribute) | Crea el atributo personalizado custom:tenant\_id (inmutable tras el alta y no escribible por los app clients). Lo asigna el backend de onboarding con AdminCreateUser; las APIs lo leen del token validado. No se puede borrar ni renombrar una vez creado. | `bool` | `false` | no |
| <a name="input_threat_protection"></a> [threat\_protection](#input\_threat\_protection) | Threat protection (solo con feature\_plan = PLUS). mode: AUDIT (solo registra) o ENFORCED; null = ENFORCED en prod y AUDIT en el resto. compromised\_credentials\_action: BLOCK o NO\_ACTION para inicio de sesión, alta y cambio de contraseña. low/medium/high\_action (autenticación adaptativa): NO\_ACTION, MFA\_IF\_CONFIGURED, MFA\_REQUIRED o BLOCK. notify (opcional): identidad SES verificada para avisar al usuario en riesgo medio y alto. | <pre>object({<br/>    mode                           = optional(string)<br/>    compromised_credentials_action = optional(string, "BLOCK")<br/>    low_action                     = optional(string, "NO_ACTION")<br/>    medium_action                  = optional(string, "MFA_IF_CONFIGURED")<br/>    high_action                    = optional(string, "MFA_REQUIRED")<br/>    notify = optional(object({<br/>      source_arn = string<br/>      from       = optional(string)<br/>      reply_to   = optional(string)<br/>    }))<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_client_ids"></a> [client\_ids](#output\_client\_ids) | ID de cada app client por clave (audience del JWT authorizer). |
| <a name="output_custom_domain_alias"></a> [custom\_domain\_alias](#output\_custom\_domain\_alias) | Destino del registro alias de Route 53 para el dominio propio (distribución de CloudFront de Cognito); null sin dominio propio. |
| <a name="output_domain_url"></a> [domain\_url](#output\_domain\_url) | URL base de managed login (authorize, token, logout); null sin dominio. |
| <a name="output_issuer_url"></a> [issuer\_url](#output\_issuer\_url) | Emisor de los JWT (iss): issuer del JWT authorizer de HTTP API y de la validación en la aplicación. |
| <a name="output_jwks_uri"></a> [jwks\_uri](#output\_jwks\_uri) | URL de las claves públicas para validar la firma de los JWT. |
| <a name="output_log_group_names"></a> [log\_group\_names](#output\_log\_group\_names) | Log group de Cognito: auth\_events (actividad con evaluación de riesgo) en PLUS o notifications (errores de envío) en el resto. |
| <a name="output_tenant_id_claim"></a> [tenant\_id\_claim](#output\_tenant\_id\_claim) | Claim con el tenant del usuario en el ID token (custom:tenant\_id); null si el pool no tiene el atributo. En el access token solo aparece si lo añade el trigger pre token generation. |
| <a name="output_user_pool_arn"></a> [user\_pool\_arn](#output\_user\_pool\_arn) | ARN del user pool (provider\_arns del autorizador COGNITO\_USER\_POOLS de REST API). |
| <a name="output_user_pool_id"></a> [user\_pool\_id](#output\_user\_pool\_id) | ID del user pool. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **MFA por pool, no por grupo.** Cognito no admite MFA obligatoria solo para un grupo: `mfa_configuration` (`null` = `ON` en prod, `OPTIONAL` fuera) afecta a todos. En prod `OFF` se rechaza y `OPTIONAL` solo se admite con PLUS y threat protection `ENFORCED`, que pide MFA según el riesgo del inicio de sesión (corrección v2.1 del plan). Para administradores con MFA obligatoria y usuarios finales sin ella, dos pools. El único factor es **TOTP** (sin SMS: coste y factor más débil). La recuperación de cuenta es solo por correo verificado.
- **Contraseñas** de 14 caracteres por defecto (mínimo validado: 12) con las cuatro clases y, en ESSENTIALS/PLUS, historial de 5. Los cambios de correo no se aplican hasta verificar el nuevo, para que no se pueda secuestrar una cuenta cambiándolo.
- **`custom:tenant_id` inmutable** (`mutable = false`): solo lo asigna el backend de onboarding con `AdminCreateUser` y ningún app client puede escribirlo (validado en `write_attributes`). Un pool con tenant no admite registro libre. Los atributos personalizados no se pueden borrar ni renombrar, y `username_attributes` es fijo: cambiarlos fuerza el reemplazo del pool, que la política de conftest bloquea (`aws_cognito_user_pool` es un recurso con estado).
- **Solo clientes públicos:** sin secreto (en el navegador no se puede proteger), `allowed_oauth_flows = ["code"]` (authorization code con PKCE; sin implicit), `explicit_auth_flows = ["ALLOW_USER_SRP_AUTH"]` (la contraseña nunca sale del cliente; sin `USER_PASSWORD_AUTH`), `prevent_user_existence_errors` y revocación de tokens. **Rotación de refresh tokens** activada por defecto (gracia de 30 s): con ella `ALLOW_REFRESH_TOKEN_AUTH` no está disponible y se refresca con `GetTokensFromRefreshToken` o `/oauth2/token`. Tokens de acceso e ID de 15–60 minutos (60 por defecto) y refresh de 1–90 días (30). Los clientes **confidenciales** no se crean en este módulo: su secreto quedaría en el estado (regla 0.1).
- **URLs de retorno** solo `https://` (o `http://localhost` fuera de prod), sin comodines.
- **Threat protection (PLUS):** `AUDIT` fuera de prod y `ENFORCED` en prod por defecto; credenciales comprometidas bloqueadas en inicio de sesión, alta y cambio de contraseña; autenticación adaptativa `NO_ACTION` / `MFA_IF_CONFIGURED` / `MFA_REQUIRED` para riesgo bajo / medio / alto, con aviso por correo si se pasa una identidad SES (`notify`). Para bajar de PLUS hay que desactivarla antes.
- **Correo:** en prod se exige SES (`DEVELOPER`); el envío de Cognito está limitado a unos 50 correos al día.
- **Logs:** una sola configuración de entrega por pool: actividad con evaluación de riesgo (`userAuthEvents`) en PLUS y errores de envío de mensajes (`userNotification`) en el resto. Con las dos, AWS las devuelve en orden no determinista y el provider falla al aplicar ("inconsistent result after apply", comprobado en la sandbox el 2026-10-14 con 6.68.0). Van a log groups bajo `/aws/vendedlogs/cognito/<pool>/`, creados por el módulo con la CMK y retención (contienen IPs e identificadores de usuario). Bajo `/aws/vendedlogs/` la entrega no depende del tamaño de la *resource policy* de CloudWatch Logs de la cuenta.
- **Managed login versión 2** con un estilo por app client (`aws_cognito_managed_login_branding` con los valores de Cognito; la marca del cliente se ajusta en consola o por variable en el blueprint). El dominio propio exige certificado ACM de **us-east-1**; `custom_domain_alias` da el destino del alias de Route 53.
- **Trigger pre token generation V2_0** (ESSENTIALS/PLUS): el módulo concede la invocación solo a `cognito-idp.amazonaws.com` con `source_arn` del pool y `source_account`.
- **SSM** (`/<project>/<env>/identity/<name>/…`): `user_pool_id`, `user_pool_arn`, `issuer` y `client_id/<clave>` (identificadores públicos que ya viajan en los tokens).

### Cómo se verificó

- 30 tests unitarios con `mock_provider`: defaults de prod y dev, historial de contraseñas según el plan, atributo de tenant inmutable, endurecimiento de los clientes públicos con y sin rotación, threat protection en PLUS (modo por entorno, credenciales comprometidas, acciones adaptativas, aviso con SES, logs de actividad), managed login con prefijo y con dominio propio, trigger V2_0 y su permiso, grupos, logs cifrados, SSM, emisor y JWKS, y 15 validaciones que deben fallar.
- **Plan real offline** contra el provider 6.67.0 (credenciales falsas; la cuenta del permiso de la Lambda sustituida por una constante) con todas las opciones (PLUS, dominio propio, trigger, grupos y dos clientes): 17 recursos aceptados por el esquema real (`refresh_token_rotation`, `managed_login_version = 2`, `pre_token_generation_config`, `aws_cognito_log_delivery_configuration`, `aws_cognito_managed_login_branding`).
- **Pendiente en sandbox** (sin coste fijo; Cognito cobra por usuario activo): `tests/integration.tftest.hcl`, [`tests/integration/tenant-isolation/cognito.sh`](../../../tests/integration/tenant-isolation/cognito.sh) (paso 4 de la aceptación: `custom:tenant_id` no se puede cambiar) y que la entrega de logs a CloudWatch se crea con un log group cifrado con CMK.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
