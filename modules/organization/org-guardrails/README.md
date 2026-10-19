# org-guardrails

SCP (y RCP opcional) de organización: protegen los servicios de seguridad, el estado de OpenTofu y los roles de CI, deniegan el usuario root y restringen las regiones.

## Uso

```hcl
module "guardrails" {
  source = "../../modules/organization/org-guardrails"

  project         = "acme"
  environment     = "prod"
  target_ids      = ["ou-abcd-12345678"]
  admin_role_arns = ["arn:aws:iam::*:role/AWSControlTowerExecution"]
  allowed_regions = ["us-east-1", "us-west-2"]
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
| [aws_organizations_policy.rcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy) | resource |
| [aws_organizations_policy.region](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy) | resource |
| [aws_organizations_policy.security](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy) | resource |
| [aws_organizations_policy_attachment.rcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy_attachment) | resource |
| [aws_organizations_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy_attachment) | resource |
| [aws_iam_policy_document.rcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.region](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.security](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_admin_role_arns"></a> [admin\_role\_arns](#input\_admin\_role\_arns) | ARNs (admiten comodines) de los roles exentos de las denegaciones: administración de la organización, Control Tower y el rol que aplica la línea base. Sin al menos uno, la organización podría quedar bloqueada. | `list(string)` | n/a | yes |
| <a name="input_allowed_regions"></a> [allowed\_regions](#input\_allowed\_regions) | Regiones en las que se permite operar. Si usas WAF/ACM de CloudFront incluye us-east-1. | `list(string)` | n/a | yes |
| <a name="input_bootstrap_role_arns"></a> [bootstrap\_role\_arns](#input\_bootstrap\_role\_arns) | ARNs de los roles que pueden modificar el estado y los roles de CI (bootstrap/break-glass). Si es vacío, usa admin\_role\_arns. | `list(string)` | `[]` | no |
| <a name="input_ci_role_name_prefix"></a> [ci\_role\_name\_prefix](#input\_ci\_role\_name\_prefix) | Prefijo de los roles de CI protegidos (<prefix>-plan-* y <prefix>-apply-*), como crea el módulo github-oidc. | `string` | `"gha"` | no |
| <a name="input_enable_resource_control_policies"></a> [enable\_resource\_control\_policies](#input\_enable\_resource\_control\_policies) | Crea además una RCP que exige TLS y limita S3/KMS/Secrets Manager/STS/SQS a principals de la organización. Requiere que RCP esté habilitado en la organización y organization\_id. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno al que aplican las políticas (p. ej. la OU Workloads/Prod). | `string` | n/a | yes |
| <a name="input_global_service_actions"></a> [global\_service\_actions](#input\_global\_service\_actions) | Acciones de servicios globales exentas de la restricción de región. | `list(string)` | <pre>[<br/>  "iam:*",<br/>  "cloudfront:*",<br/>  "route53:*",<br/>  "route53domains:*",<br/>  "waf:*",<br/>  "sts:*",<br/>  "organizations:*",<br/>  "support:*",<br/>  "budgets:*",<br/>  "ce:*",<br/>  "account:*",<br/>  "billing:*",<br/>  "cur:*",<br/>  "health:*",<br/>  "pricing:*",<br/>  "shield:*",<br/>  "trustedadvisor:*"<br/>]</pre> | no |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | ID de la organización (o-xxxxxxxxxx). Obligatorio con enable\_resource\_control\_policies. | `string` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de políticas. | `string` | n/a | yes |
| <a name="input_state_bucket_arns"></a> [state\_bucket\_arns](#input\_state\_bucket\_arns) | ARNs de los buckets de estado a proteger (vacío = no se añade la protección). | `list(string)` | `[]` | no |
| <a name="input_state_kms_key_arns"></a> [state\_kms\_key\_arns](#input\_state\_kms\_key\_arns) | ARNs de las claves KMS de estado a proteger (vacío = no se añade la protección). | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales de las políticas. | `map(string)` | `{}` | no |
| <a name="input_target_ids"></a> [target\_ids](#input\_target\_ids) | IDs de OU (ou-...), raíz (r-...) o cuenta (12 dígitos) a los que se adjuntan las políticas. Cada destino admite como máximo 5 SCP incluida FullAWSAccess: este módulo usa 2. | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_rcp_policy_id"></a> [rcp\_policy\_id](#output\_rcp\_policy\_id) | ID de la RCP (null si no está habilitada). |
| <a name="output_region_policy_id"></a> [region\_policy\_id](#output\_region\_policy\_id) | ID de la SCP de restricción de regiones. |
| <a name="output_security_policy_id"></a> [security\_policy\_id](#output\_security\_policy\_id) | ID de la SCP de seguridad. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

Se aplica desde la **cuenta de management** de la organización. Crea **dos SCP** por destino (más `FullAWSAccess`, que AWS exige: el máximo es 5 por OU/cuenta) y, opcionalmente, una RCP.

| Política | Contenido |
|---|---|
| `…-guardrails-security` | `DenyLeaveOrganization`; `ProtectSecurityServices` (CloudTrail, GuardDuty, Security Hub, Config, Access Analyzer); `DenyRootUser`; protección del bucket/clave de estado y de los roles de CI (`<prefix>-plan-*`, `<prefix>-apply-*`) |
| `…-guardrails-region` | Deniega todo fuera de `allowed_regions`, salvo servicios globales (`global_service_actions`) |
| `…-guardrails-data-perimeter` (RCP, opcional) | Exige TLS y limita S3/KMS/Secrets Manager a principals de la organización |

- **Exenciones:** todas las denegaciones, salvo root, usan `ArnNotLike aws:PrincipalArn` con `admin_role_arns` (o `bootstrap_role_arns` en la protección de estado y roles de CI). `admin_role_arns` es obligatorio: sin una excepción, una SCP puede dejar la organización sin nadie que pueda corregirla. Incluye el rol que aplica la línea base y el de Control Tower.
- **No metas el rol `gha-apply-*` en `bootstrap_role_arns`:** el objetivo de esa protección es que CI no pueda tocar el estado ni sus propios roles.
- Una SCP no puede condicionar `guardduty:UpdateDetector` por `Enable=false`, así que se deniega completa (y `cloudtrail:UpdateTrail`): los cambios de configuración los hace un rol exento.
- La restricción de región exime servicios globales; si usas WAF/ACM de CloudFront, incluye `us-east-1` en `allowed_regions`.
- Tamaño: cada política tiene una precondición de 5120 caracteres (límite de AWS). Con la configuración del ejemplo ocupan 2421, 553 y 488.
- **RCP (`enable_resource_control_policies`):** desactivada por defecto. Antes de activarla, comprueba que ningún servicio escribe con un principal que no sea de servicio ni de la organización: p. ej. los logs de ALB en regiones antiguas los entrega una cuenta de AWS (no un principal de servicio) y quedarían bloqueados. Requiere habilitar el tipo de política RCP en la organización.
- **Siempre prueba en una OU vacía primero:** una SCP mal escrita bloquea acciones de todas las cuentas del destino. Valida el efecto con el simulador de políticas o una cuenta de pruebas antes de adjuntarla a producción.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
