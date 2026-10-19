# acm-certificate

Certificado ACM validado por DNS, con registros en Route 53 o emitidos como salida para DNS externo.

## Uso

```hcl
module "certificate" {
  source    = "../../modules/edge/acm-certificate"
  providers = { aws = aws.us_east_1 } # para CloudFront; sin alias para el ALB

  project     = "acme"
  environment = "prod"
  domain_name = "app.cliente.com"
  zone_id     = var.zone_id # null si el DNS no está en Route 53
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
| [aws_acm_certificate.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_route53_record.validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Dominio principal del certificado (p. ej. app.cliente.com). | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_key_algorithm"></a> [key\_algorithm](#input\_key\_algorithm) | Algoritmo de la clave del certificado. RSA\_2048 es el más compatible; EC\_prime256v1 es más ligero y lo admiten CloudFront y ALB. | `string` | `"RSA_2048"` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_subject_alternative_names"></a> [subject\_alternative\_names](#input\_subject\_alternative\_names) | Nombres alternativos adicionales (no repitas domain\_name). | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_wait_for_validation"></a> [wait\_for\_validation](#input\_wait\_for\_validation) | Espera a que el certificado esté emitido. Con zone\_id se espera siempre; con DNS externo actívalo en un segundo apply, cuando los registros de validation\_records ya existan (si no, el apply se bloquearía). | `bool` | `false` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | ID de la zona alojada de Route 53 donde crear los registros de validación. Si es null, el módulo no crea registros: los emite en validation\_records para crearlos a mano. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_certificate_arn"></a> [certificate\_arn](#output\_certificate\_arn) | ARN del certificado. Con validación activa solo se devuelve cuando el certificado ya está emitido. |
| <a name="output_domain_name"></a> [domain\_name](#output\_domain\_name) | Dominio principal del certificado. |
| <a name="output_validation_records"></a> [validation\_records](#output\_validation\_records) | Registros DNS de validación por dominio (para crear a mano si el DNS no está en Route 53). |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- Validación **solo por DNS** (nunca por correo) y `create_before_destroy` para renovar sin cortes. La clave es RSA_2048 por defecto (la más compatible); `EC_prime256v1` es válida para CloudFront y ALB.
- **Dos instancias para el mismo dominio:** una con el provider de `us-east-1` (certificado del *viewer* en CloudFront) y otra con el provider regional (certificado del listener HTTPS del ALB, imprescindible con `https-only` hacia el origen; ADR 0007).
- Con `zone_id` el módulo crea un registro por dominio de entrada y espera a la emisión. Sin `zone_id` (DNS externo) **no crea registros ni bloquea el apply**: emite `validation_records` y deja el certificado pendiente; ver el procedimiento en el runbook `docs/runbooks/external-dns-validation.md`.
- Los registros de validación se indexan por el dominio de entrada, no por `domain_validation_options` (desconocido hasta crear el certificado), y usan `allow_overwrite` porque `example.com` y `*.example.com` comparten el mismo registro.
- Mientras el certificado esté pendiente, `certificate_arn` devuelve un ARN que **CloudFront y el listener todavía no pueden usar**: aplica los consumidores solo después de la segunda pasada.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
