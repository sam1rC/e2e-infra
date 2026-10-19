# saas-t2 / edge

Capa `edge` de SaaS T2: envuelve sin cambios la capa `edge` de [`ecommerce-t2`](../../ecommerce-t2/edge/README.md).

Mismas variables, salidas y rutas SSM que la capa de E-commerce T2 (ADR 0016, punto 6).

## Uso

Composición de referencia (equivale a `live/<env>/edge` de la fase 10): [`../examples/complete/edge`](../examples/complete/edge).

- **Lee de SSM:** lo mismo que `ecommerce-t2/edge`.
- **Publica en SSM:** lo mismo que `ecommerce-t2/edge`.

Visión general del blueprint, orden de despliegue y objetivos de resiliencia: [`../README.md`](../README.md). Composición entre capas: ADR [0016](../../../docs/adr/0016-blueprint-composition.md).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.30, < 7.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_edge"></a> [edge](#module\_edge) | ../../ecommerce-t2/edge | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alarm_emails"></a> [alarm\_emails](#input\_alarm\_emails) | Correos del topic de alarmas de borde (us-east-1: las métricas de CloudFront y del WAF global solo existen allí). En prod, al menos uno. | `list(string)` | `[]` | no |
| <a name="input_content_security_policy"></a> [content\_security\_policy](#input\_content\_security\_policy) | Content-Security-Policy de la aplicación. null = sin la cabecera. | `string` | `null` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Dominio público de la tienda (alias de CloudFront). Debe coincidir con el de la capa app, cuyo ALB lleva su certificado regional. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_price_class"></a> [price\_class](#input\_price\_class) | Clase de precio de CloudFront. | `string` | `"PriceClass_100"` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto (cliente); prefijo de los nombres de recursos y de las rutas SSM. | `string` | n/a | yes |
| <a name="input_static_path_patterns"></a> [static\_path\_patterns](#input\_static\_path\_patterns) | Rutas servidas con caché (CachingOptimized); el resto va al ALB sin caché. | `list(string)` | <pre>[<br/>  "/static/*",<br/>  "/assets/*"<br/>]</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales para los recursos (las obligatorias van en default\_tags del provider, en live/). | `map(string)` | `{}` | no |
| <a name="input_viewer_certificate_arn"></a> [viewer\_certificate\_arn](#input\_viewer\_certificate\_arn) | Certificado ACM emitido en us-east-1 para domain\_name. null = el blueprint lo emite en zone\_id. | `string` | `null` | no |
| <a name="input_waf"></a> [waf](#input\_waf) | Opciones del Web ACL de CloudFront: rules\_mode (block o count; null = count en dev y block en el resto, plan 9.2), rate\_limit\_per\_5m por IP, count\_size\_restrictions\_body (subida de archivos), anonymous\_ip\_list\_mode (off/count/block) y bot\_control (coste por petición). | <pre>object({<br/>    rules_mode                   = optional(string)<br/>    rate_limit_per_5m            = optional(number, 2000)<br/>    count_size_restrictions_body = optional(bool, false)<br/>    anonymous_ip_list_mode       = optional(string, "off")<br/>    bot_control                  = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Zona de Route 53: valida el certificado del viewer y crea los alias A/AAAA. null = DNS externo (viewer\_certificate\_arn obligatorio). | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alarm_topic_arn"></a> [alarm\_topic\_arn](#output\_alarm\_topic\_arn) | Topic de alarmas de borde (us-east-1). |
| <a name="output_distribution_domain_name"></a> [distribution\_domain\_name](#output\_distribution\_domain\_name) | Dominio *.cloudfront.net (destino del CNAME si el DNS es externo). |
| <a name="output_distribution_id"></a> [distribution\_id](#output\_distribution\_id) | ID de la distribución. |
| <a name="output_web_acl_arn"></a> [web\_acl\_arn](#output\_web\_acl\_arn) | Web ACL de CloudFront. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

Las de [`ecommerce-t2/edge`](../../ecommerce-t2/edge/README.md).

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
