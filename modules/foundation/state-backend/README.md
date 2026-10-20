# state-backend

Bucket de estado de OpenTofu (S3 versionado, SSE-KMS, TLS-only, bloqueo público) y su CMK `alias/<project>-<environment>-state`. Se aplica una vez por cuenta/entorno durante el bootstrap, con estado local que luego se migra al propio bucket (ver `docs/runbooks/bootstrap.md`).

## Uso

```hcl
module "state_backend" {
  source = "../../modules/foundation/state-backend"

  project     = "acme"
  environment = "dev"
}

output "backend_config" {
  value = module.state_backend.backend_config
}
```

El output `backend_config` contiene el bloque `backend "s3"` (con `use_lockfile = true`, sin DynamoDB) y el bloque `encryption` de OpenTofu con `enforced = true` para `state` y `plan`, listo para pegar en `backend.tf` (sustituye `<layer>`).

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
| <a name="module_bucket"></a> [bucket](#module\_bucket) | ../../storage/s3-bucket | n/a |
| <a name="module_kms"></a> [kms](#module\_kms) | ../kms-key | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_kms_admin_principal_arns"></a> [kms\_admin\_principal\_arns](#input\_kms\_admin\_principal\_arns) | ARNs que administran la clave de estado (sin permiso de uso). | `list(string)` | `[]` | no |
| <a name="input_kms_user_principal_arns"></a> [kms\_user\_principal\_arns](#input\_kms\_user\_principal\_arns) | ARNs con permiso de uso explícito sobre la clave de estado. Los roles de CI no lo necesitan si su política IAM incluye kms:Decrypt/GenerateDataKey: la key policy delega en IAM. | `list(string)` | `[]` | no |
| <a name="input_noncurrent_version_retention_days"></a> [noncurrent\_version\_retention\_days](#input\_noncurrent\_version\_retention\_days) | Días que se conservan las versiones anteriores del estado. | `number` | `90` | no |
| <a name="input_object_lock_days"></a> [object\_lock\_days](#input\_object\_lock\_days) | Días de retención por defecto con Object Lock en modo GOVERNANCE (null = sin Object Lock). Solo se puede activar al crear el bucket. | `number` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_backend_config"></a> [backend\_config](#output\_backend\_config) | Bloque terraform { backend + encryption } sugerido para backend.tf (sustituye <layer>). |
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN del bucket de estado. |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | Nombre del bucket de estado. |
| <a name="output_kms_alias_name"></a> [kms\_alias\_name](#output\_kms\_alias\_name) | Alias de la CMK de estado. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN de la CMK de estado. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- Doble cifrado: el objeto en S3 va con SSE-KMS y, además, el contenido del estado y de los planes se cifra en cliente con el bloque `encryption` (OpenTofu). El estado es ilegible sin acceso a la CMK. **Es exclusivo de OpenTofu**; Terraform no podrá leerlo.
- La CMK tiene rotación anual y delega en IAM: los roles de CI (módulo `github-oidc`) reciben sus permisos de `kms:*` por política IAM, así que no hay dependencia circular entre la clave y los roles.
- Object Lock opcional (`object_lock_days`, modo GOVERNANCE) para entornos que exijan inmutabilidad del estado.
- Se conservan 90 días de versiones anteriores por defecto, para recuperar un estado corrupto.
- El nombre del bucket incluye el ID de cuenta (`<project>-<env>-tfstate-<account_id>`) para evitar colisiones globales y ataques de *bucket squatting*.
- Haz copia de seguridad de la configuración de la clave: perder la CMK implica perder el estado.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
