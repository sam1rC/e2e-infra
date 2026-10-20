# waf-web-acl

AWS WAFv2 Web ACL (CLOUDFRONT o REGIONAL) con grupos gestionados de AWS, límites de tasa por IP y por tenant, Bot Control, Anti-DDoS, IPs anónimas y verificación de origen opcionales, y logs con campos sensibles redactados.

## Uso

```hcl
# Web ACL de CloudFront: instanciar con el provider de us-east-1
module "waf" {
  source    = "../../modules/edge/waf-web-acl"
  providers = { aws = aws.us_east_1 }

  project     = "acme"
  environment = "prod"
  scope       = "CLOUDFRONT"
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
| [aws_cloudwatch_log_group.waf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_wafv2_web_acl.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association) | resource |
| [aws_wafv2_web_acl_logging_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_logging_configuration) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_anonymous_ip_list_mode"></a> [anonymous\_ip\_list\_mode](#input\_anonymous\_ip\_list\_mode) | AWSManagedRulesAnonymousIpList (VPN, Tor, proveedores de hosting) con prioridad 15: off, count (solo registra; empieza aquí) o block. Ojo: HostingProviderIPList bloquea tráfico servidor a servidor, como los webhooks de la pasarela de pagos; exclúyelos antes de pasar a block. | `string` | `"off"` | no |
| <a name="input_anti_ddos"></a> [anti\_ddos](#input\_anti\_ddos) | Añade AWSManagedRulesAntiDDoSRuleSet con prioridad 1 (antes que el resto, como recomienda AWS). Tiene coste adicional por petición: T1 o clientes con riesgo de inundaciones HTTP. sensitivity\_to\_block (regla DDoSRequests) y challenge\_sensitivity (ChallengeDDoSRequests) en LOW\|MEDIUM\|HIGH: bloqueo conservador y challenge silencioso más amplio por defecto. exempt\_uri\_regexes son las URIs que no pueden resolver un challenge (API JSON y estáticos); revísalas por cliente: solo DDoSRequests puede bloquearlas. null = desactivado. | <pre>object({<br/>    sensitivity_to_block  = optional(string, "LOW")<br/>    challenge_enabled     = optional(bool, true)<br/>    challenge_sensitivity = optional(string, "HIGH")<br/>    exempt_uri_regexes    = optional(list(string), ["^/api/", "\\.(css|gif|ico|jpe?g|js|json|map|mp[34]|otf|pdf|png|svg|ttf|txt|webm|webp|woff2?|xml)$"])<br/>  })</pre> | `null` | no |
| <a name="input_association_arns"></a> [association\_arns](#input\_association\_arns) | Recursos regionales a asociar (nombre estable => ARN), p. ej. el stage de API Gateway. Solo con scope = REGIONAL. | `map(string)` | `{}` | no |
| <a name="input_count_size_restrictions_body"></a> [count\_size\_restrictions\_body](#input\_count\_size\_restrictions\_body) | Deja SizeRestrictions\_BODY de CommonRuleSet en modo count. Actívalo si los clientes suben archivos (el límite del cuerpo es de 8 KB). | `bool` | `false` | no |
| <a name="input_create_web_acl"></a> [create\_web\_acl](#input\_create\_web\_acl) | Crea el Web ACL. Ponlo en false cuando el WAF viene incluido en un plan flat-rate de CloudFront que se configura fuera de IaC (ver README). | `bool` | `true` | no |
| <a name="input_enable_bot_control"></a> [enable\_bot\_control](#input\_enable\_bot\_control) | Añade AWSManagedRulesBotControlRuleSet (nivel COMMON). Tiene coste adicional por petición: solo T1. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_log_kms_key_arn"></a> [log\_kms\_key\_arn](#input\_log\_kms\_key\_arn) | CMK con la que se cifra el grupo de logs (debe autorizar a logs.<región>.amazonaws.com). null = cifrado por defecto de CloudWatch Logs. | `string` | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retención de los logs del WAF en CloudWatch Logs. | `number` | `90` | no |
| <a name="input_managed_rules_mode"></a> [managed\_rules\_mode](#input\_managed\_rules\_mode) | block aplica las acciones de los grupos gestionados y de las reglas de tasa; count solo las registra (recomendado en dev para probar reglas nuevas antes de bloquear). La verificación de origen siempre bloquea. | `string` | `"block"` | no |
| <a name="input_origin_verify"></a> [origin\_verify](#input\_origin\_verify) | Bloquea las peticiones que no lleven la cabecera de verificación de origen con el valor esperado (REST API de SaaS T3 detrás de CloudFront). El secreto acaba en el estado (cifrado) y en la configuración del Web ACL: es un token de verificación, no una credencial de datos (ADR 0010). | <pre>object({<br/>    header_name = optional(string, "x-origin-verify")<br/>    secret      = string<br/>  })</pre> | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_rate_limit_per_5m"></a> [rate\_limit\_per\_5m](#input\_rate\_limit\_per\_5m) | Peticiones máximas por IP en 5 minutos antes de bloquear. | `number` | `2000` | no |
| <a name="input_scope"></a> [scope](#input\_scope) | Ámbito del Web ACL: CLOUDFRONT (instanciar con el provider de us-east-1) o REGIONAL (API Gateway REST, ALB...). | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_tenant_rate_limit"></a> [tenant\_rate\_limit](#input\_tenant\_rate\_limit) | Segunda regla de tasa por cabecera de tenant (SaaS): limit peticiones en 5 minutos por valor de la cabecera. null = desactivada. | <pre>object({<br/>    header_name = string<br/>    limit       = number<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | Grupo de CloudWatch Logs con los logs del WAF (null si create\_web\_acl = false). |
| <a name="output_web_acl_arn"></a> [web\_acl\_arn](#output\_web\_acl\_arn) | ARN del Web ACL (null si create\_web\_acl = false). |
| <a name="output_web_acl_id"></a> [web\_acl\_id](#output\_web\_acl\_id) | ID del Web ACL (null si create\_web\_acl = false). |
| <a name="output_web_acl_name"></a> [web\_acl\_name](#output\_web\_acl\_name) | Nombre del Web ACL (null si create\_web\_acl = false). |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Reglas con prioridad fija** (quitar o añadir una no renumera las demás): 10 `AmazonIpReputationList`, 20 `CommonRuleSet`, 30 `KnownBadInputsRuleSet`, 40 `SQLiRuleSet`, 50 límite por IP (2000 peticiones/5 min por defecto) y, opcionales, 1 `AntiDDoSRuleSet` (antes que cualquier otra regla, como recomienda AWS, para que mida todo el tráfico; coste por petición), 5 verificación de origen, 15 `AnonymousIpList` (empezar en `count`: su regla `HostingProviderIPList` bloquearía webhooks de la pasarela de pagos y otro tráfico servidor a servidor), 55 límite por cabecera de tenant (SaaS) y 60 `BotControl` (nivel COMMON, coste por petición: solo T1).
- **Anti-DDoS:** bloqueo con sensibilidad `LOW` (solo los participantes más evidentes) y challenge silencioso en `HIGH` (mitigación suave). El challenge solo lo resuelven navegadores que esperan HTML: las URIs de API (`^/api/`) y de estáticos quedan exentas por defecto y solo las puede bloquear la regla `DDoSRequests`. Sin scope-down (AWS lo desaconseja: falsea la línea base de tráfico). Probar en `count` (`managed_rules_mode`) antes de producción.
- **`managed_rules_mode = "count"`** (para dev): los grupos gestionados y las reglas de tasa solo registran, no bloquean, para probar reglas nuevas antes de activarlas. `staging` y `prod` usan `block`.
- `count_size_restrictions_body` deja `SizeRestrictions_BODY` en count: actívalo si los clientes suben archivos (el límite del cuerpo del grupo común es de 8 KB).
- **Logs a CloudWatch Logs** (`aws-waf-logs-<nombre>`) con `authorization` y `cookie` redactadas (y la cabecera de verificación de origen si existe). Cifra el grupo con `log_kms_key_arn`, cuya key policy debe autorizar a `logs.<región>.amazonaws.com`.
- **Verificación de origen (`origin_verify`, solo `REGIONAL`):** bloquea las peticiones sin la cabecera `x-origin-verify` con el valor esperado, para que una REST API no se pueda llamar saltándose CloudFront. WAF solo admite el valor literal en la regla, así que el secreto queda en el estado (cifrado por el bloque `encryption`) y en la configuración del Web ACL: es un token de verificación rotable, no una credencial de datos (ADR 0010). La regla no registra muestras de peticiones para no volcar el valor.
- **Plan flat-rate de CloudFront:** el WAF viene incluido en el plan y se configura desde él; no se ha comprobado que el provider gestione ese plan, así que es un paso manual del runbook. Con `create_web_acl = false` el módulo no crea nada y sus outputs son `null`.
- **CloudFront** asocia el Web ACL desde la distribución (`web_acl_id`); `association_arns` es solo para recursos regionales.

### Cómo se verificó

- 22 tests unitarios con `mock_provider` (incluye Anti-DDoS con prioridad 1 y su configuración, la lista de IPs anónimas en count/block y sus validaciones).
- Un `tofu plan` real sin credenciales (el módulo no usa data sources) con todas las opciones activadas (`REGIONAL`, Bot Control, Anti-DDoS, IPs anónimas, límite por tenant, verificación de origen y asociación) es aceptado por el provider 6.67.0.
- **Pendiente en sandbox:** una petición con `' OR 1=1--` en la query string devuelve 403 (criterio de aceptación de la fase) y el funcionamiento real de la regla `origin-verify`.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
