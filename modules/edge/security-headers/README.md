# security-headers

CloudFront response headers policy con las cabeceras de seguridad estándar (HSTS, nosniff, frame DENY, referrer policy y CSP opcional).

## Uso

```hcl
module "security_headers" {
  source = "../../modules/edge/security-headers"

  project     = "acme"
  environment = "prod"

  content_security_policy = "default-src 'self'; frame-ancestors 'none'"
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
| [aws_cloudfront_response_headers_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_response_headers_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_content_security_policy"></a> [content\_security\_policy](#input\_content\_security\_policy) | Valor de Content-Security-Policy. Depende de la aplicación, por eso no hay valor por defecto: null no envía la cabecera. | `string` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_hsts_max_age_seconds"></a> [hsts\_max\_age\_seconds](#input\_hsts\_max\_age\_seconds) | max-age de Strict-Transport-Security. 63072000 (2 años) es el valor exigido para entrar en la lista de preload. | `number` | `63072000` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_policy_id"></a> [policy\_id](#output\_policy\_id) | ID de la response headers policy (para response\_headers\_policy\_id de los comportamientos). |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

Módulo compartido por `cloudfront-vpc-origin` y `cloudfront-static-site` (el plan exige la misma política en ambos). No figuraba en la estructura original del catálogo: se añade para no duplicar la política en dos módulos.

- `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload`. **`preload` compromete a todo el dominio y sus subdominios a servirse por HTTPS** y es difícil de revertir si el dominio se envía a la lista de preload de los navegadores; comprueba que ningún subdominio necesita HTTP antes de enviarlo.
- `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY` y `Referrer-Policy: strict-origin-when-cross-origin`.
- `Content-Security-Policy` depende de la aplicación: es una variable sin valor por defecto (sin ella, la cabecera no se envía). Empieza por una política estricta y relájala solo con lo que la app necesita.
- Todas las cabeceras usan `override = true`: si el origen envía otra, prevalece la de la policy.
- CloudFront no admite etiquetas en este recurso, por eso el módulo no tiene la variable `tags`.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
