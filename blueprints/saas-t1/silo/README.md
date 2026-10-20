# saas-t1 / silo

Cimientos de la cuenta de un tenant silo de SaaS T1: CMK dedicada, rol de despliegue para el pipeline del control plane y presupuesto de la cuenta.

Se aplica una vez por tenant en su cuenta (rol de bootstrap de la capa `security`, después de `account-baseline`). Luego las capas `app-network`, `app-data`, `app-app` (`isolation_model = "silo"`, `tenant_id`) y `app-edge` se despliegan en esa cuenta con un directorio de `live/` por tenant.

## Uso

Composición de referencia (equivale a `live/<env>/silo` de la fase 10): [`../examples/complete/silo`](../examples/complete/silo).

En la sandbox actual se valida con `plan` y tests unitarios (necesita un rol de CI de otra cuenta).

- **Lee de SSM:** —
- **Publica en SSM:** `tenant/tenant_id`, `tenant/kms_key_arn`, `tenant/deploy_role_arn`.

Visión general del blueprint, orden de despliegue y objetivos de resiliencia: [`../README.md`](../README.md). Composición entre capas: ADR [0016](../../../docs/adr/0016-blueprint-composition.md).

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

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_budget"></a> [budget](#module\_budget) | ../../../modules/foundation/budgets | n/a |
| <a name="module_deploy_role"></a> [deploy\_role](#module\_deploy\_role) | ../../../modules/organization/cross-account-role | n/a |
| <a name="module_tenant_kms"></a> [tenant\_kms](#module\_tenant\_kms) | ../../../modules/foundation/kms-key | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ssm_parameter.layer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_budget"></a> [budget](#input\_budget) | Presupuesto mensual de la cuenta del tenant (coste dedicado, base de la facturación del tier premium) y correos de aviso. | <pre>object({<br/>    monthly_limit_usd            = number<br/>    alert_emails                 = list(string)<br/>    existing_anomaly_monitor_arn = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_deploy_role"></a> [deploy\_role](#input\_deploy\_role) | Rol que asume el pipeline del control plane (GitHub Actions con OIDC en la cuenta de CI) para desplegar las capas del tenant: roles de confianza, políticas gestionadas y permissions boundary (obligatoria: el rol puede crear roles IAM). organization\_id limita la confianza a la organización. | <pre>object({<br/>    trusted_role_arns        = list(string)<br/>    managed_policy_arns      = optional(map(string), { admin = "arn:aws:iam::aws:policy/AdministratorAccess" })<br/>    permissions_boundary_arn = string<br/>    organization_id          = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto (cliente); prefijo de los nombres de recursos y de las rutas SSM. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales para los recursos (las obligatorias van en default\_tags del provider, en live/). | `map(string)` | `{}` | no |
| <a name="input_tenant_id"></a> [tenant\_id](#input\_tenant\_id) | Tenant premium dueño de esta cuenta (etiqueta Tenant, alias de la CMK y parámetro SSM). Las capas app-* del blueprint se despliegan después en esta misma cuenta. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_budget_name"></a> [budget\_name](#output\_budget\_name) | Presupuesto mensual de la cuenta del tenant. |
| <a name="output_deploy_role_arn"></a> [deploy\_role\_arn](#output\_deploy\_role\_arn) | Rol que asume el pipeline del control plane para desplegar las capas del tenant. |
| <a name="output_tenant_kms_key_arn"></a> [tenant\_kms\_key\_arn](#output\_tenant\_kms\_key\_arn) | CMK dedicada del tenant. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- CMK por tenant: sus datos no comparten clave con otros tenants.
- El rol de despliegue solo confía en el rol de CI indicado (opcionalmente limitado a la organización) y exige permissions boundary, porque crea roles IAM.
- Presupuesto con avisos y detección de anomalías por cuenta de tenant.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
