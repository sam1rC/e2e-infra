# kms-key

Clave KMS gestionada por el cliente (CMK) con rotación anual, política explícita y alias `alias/<project>-<environment>-<purpose>`. Una por entorno y propósito (`state`, `data`, `logs`, ...).

## Uso

```hcl
module "kms" {
  source = "../../modules/foundation/kms-key"

  project     = "acme"
  environment = "dev"
  purpose     = "data"
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
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_additional_policy_documents"></a> [additional\_policy\_documents](#input\_additional\_policy\_documents) | Documentos de política JSON que se fusionan en la key policy, para declaraciones exactas que exige un servicio (p. ej. CloudTrail con aws:SourceArn y contexto de cifrado). Los Sid deben ser únicos y distintos de los del módulo. | `list(string)` | `[]` | no |
| <a name="input_admin_principal_arns"></a> [admin\_principal\_arns](#input\_admin\_principal\_arns) | ARNs de los principals que administran la clave (sin permiso de uso). Si es vacío, solo la raíz de la cuenta (que delega en IAM) puede administrarla. | `list(string)` | `[]` | no |
| <a name="input_deletion_window_in_days"></a> [deletion\_window\_in\_days](#input\_deletion\_window\_in\_days) | Días de espera antes de borrar la clave definitivamente. | `number` | `30` | no |
| <a name="input_description"></a> [description](#input\_description) | Descripción de la clave. Si es null se genera a partir de project/environment/purpose. | `string` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_multi_region"></a> [multi\_region](#input\_multi\_region) | Crea una clave multi-región (solo si hay una réplica prevista, p. ej. copias de backup cross-region). | `bool` | `false` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_purpose"></a> [purpose](#input\_purpose) | Propósito de la clave (state, data, logs, ...); forma parte del alias. | `string` | n/a | yes |
| <a name="input_service_principals"></a> [service\_principals](#input\_service\_principals) | Servicios AWS (p. ej. s3.amazonaws.com, logs.<region>.amazonaws.com) que usan la clave directamente como principal de servicio. El acceso de principals de la cuenta vía servicio (kms:ViaService) se define con via\_services. | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales para la clave. | `map(string)` | `{}` | no |
| <a name="input_user_principal_arns"></a> [user\_principal\_arns](#input\_user\_principal\_arns) | ARNs de los principals que pueden usar la clave (Encrypt/Decrypt/GenerateDataKey*/DescribeKey). | `list(string)` | `[]` | no |
| <a name="input_via_services"></a> [via\_services](#input\_via\_services) | Servicios (p. ej. s3.us-east-1.amazonaws.com) a través de los cuales cualquier principal de la cuenta puede usar la clave (kms:ViaService + kms:CallerAccount). | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alias_name"></a> [alias\_name](#output\_alias\_name) | Alias de la clave (alias/<project>-<environment>-<purpose>). |
| <a name="output_key_arn"></a> [key\_arn](#output\_key\_arn) | ARN de la clave KMS. |
| <a name="output_key_id"></a> [key\_id](#output\_key\_id) | ID de la clave KMS. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- Rotación automática activada con periodo de 365 días; ventana de borrado de 30 días por defecto (mínimo 7).
- La política de clave delega en IAM de la cuenta (`EnableAccountRootAndIam`); esa es la forma estándar y no concede acceso por sí sola a nadie sin una política IAM.
- Administración y uso están separados: `admin_principal_arns` no puede cifrar/descifrar y `user_principal_arns` no puede administrar.
- Los principals de servicio (`service_principals`) llevan `aws:SourceAccount` para evitar el confused deputy.
- `via_services` permite a cualquier principal **de la propia cuenta** usar la clave solo a través del servicio indicado (`kms:ViaService` + `kms:CallerAccount`).
- `additional_policy_documents` fusiona declaraciones exactas que exige un servicio (p. ej. CloudTrail con `aws:SourceArn` y contexto de cifrado). Revísalas como cualquier otra key policy: se suman a las del módulo.
- `multi_region = false` por defecto; actívalo solo si hay una réplica prevista (p. ej. copias de AWS Backup cross-region).

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
