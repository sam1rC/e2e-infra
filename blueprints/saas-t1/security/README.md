# saas-t1 / security

Capa de organización de SaaS T1 (cuenta de management): OU, cuentas miembro (`org-account`), SCP por OU (`org-guardrails`) y administración delegada de GuardDuty, Security Hub, Config, Access Analyzer e Inspector en la cuenta `security`.

Prerrequisito: AWS Organizations (idealmente Control Tower) con el acceso de confianza de esos servicios habilitado. Las cuentas que ya existan se importan (`tofu import`). Después, `account-baseline` se aplica en cada cuenta desde `live/_baseline/<cuenta>` con el rol de bootstrap que devuelve esta capa.

## Uso

Composición de referencia (equivale a `live/<env>/security` de la fase 10): [`../examples/complete/security`](../examples/complete/security).

Solo se puede aplicar en la cuenta de management de una organización: en la sandbox actual se valida con `plan` y tests unitarios.

- **Lee de SSM:** —
- **Publica en SSM:** — (las salidas `account_ids`/`bootstrap_role_arns` alimentan `live/`).

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
| <a name="module_accounts"></a> [accounts](#module\_accounts) | ../../../modules/organization/org-account | n/a |
| <a name="module_guardrails"></a> [guardrails](#module\_guardrails) | ../../../modules/organization/org-guardrails | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_guardduty_organization_admin_account.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/guardduty_organization_admin_account) | resource |
| [aws_inspector2_delegated_admin_account.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/inspector2_delegated_admin_account) | resource |
| [aws_organizations_delegated_administrator.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_delegated_administrator) | resource |
| [aws_organizations_organizational_unit.infrastructure](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_organizational_unit.nonprod](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_organizational_unit.prod](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_organizational_unit.security](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_organizational_unit.silo](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_organizational_unit.workloads](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_securityhub_organization_admin_account.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/securityhub_organization_admin_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_accounts"></a> [accounts](#input\_accounts) | Cuentas miembro por clave estable (security, log-archive, control-plane, app-nonprod, app-prod, silo-<tenant>): correo raíz único, OU (security, infrastructure, nonprod, prod o silo), entorno y tenant (solo silo). Las cuentas existentes de Control Tower se importan con `tofu import`, no se recrean. | <pre>map(object({<br/>    email       = string<br/>    ou          = string<br/>    environment = optional(string, "prod")<br/>    tenant_id   = optional(string)<br/>  }))</pre> | n/a | yes |
| <a name="input_delegated_admins"></a> [delegated\_admins](#input\_delegated\_admins) | Delega en la cuenta security la administración de GuardDuty, Security Hub, Config, IAM Access Analyzer e Inspector para toda la organización (cada servicio necesita el acceso de confianza de Organizations habilitado). | `bool` | `true` | no |
| <a name="input_guardrails"></a> [guardrails](#input\_guardrails) | SCP de org-guardrails: roles de administración exentos (Control Tower, bootstrap), regiones permitidas (incluye us-east-1 por CloudFront/ACM/WAF) y RCP opcional (requiere organization\_id). | <pre>object({<br/>    admin_role_arns          = list(string)<br/>    allowed_regions          = list(string)<br/>    enable_rcp               = optional(bool, false)<br/>    organization_id          = optional(string)<br/>    bootstrap_role_arns      = optional(list(string), [])<br/>    protected_state_buckets  = optional(list(string), [])<br/>    protected_state_kms_keys = optional(list(string), [])<br/>  })</pre> | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto (cliente); prefijo de cuentas, OU y políticas. | `string` | n/a | yes |
| <a name="input_root_id"></a> [root\_id](#input\_root\_id) | ID de la raíz de la organización (r-...). La organización (y el acceso de confianza de GuardDuty, Security Hub, Config, Access Analyzer e Inspector) existe antes: Control Tower o un paso manual del runbook. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_account_ids"></a> [account\_ids](#output\_account\_ids) | ID de cada cuenta miembro, por clave (allowed\_account\_ids de las composiciones de live/). |
| <a name="output_bootstrap_role_arns"></a> [bootstrap\_role\_arns](#output\_bootstrap\_role\_arns) | Rol de bootstrap de cada cuenta (aplicar account-baseline y los roles de despliegue; después, IAM Identity Center). |
| <a name="output_ou_ids"></a> [ou\_ids](#output\_ou\_ids) | ID de cada OU (security, infrastructure, nonprod, prod, silo). |
| <a name="output_security_account_id"></a> [security\_account\_id](#output\_security\_account\_id) | Cuenta de administración delegada de los servicios de seguridad. |
| <a name="output_silo_account_ids"></a> [silo\_account\_ids](#output\_silo\_account\_ids) | Cuentas silo por tenant\_id (las usa el control plane para desplegar la infraestructura dedicada). |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- Separación de funciones (A8): `management` sin cargas; `security` agrega hallazgos de la organización; `log-archive` aparte.
- SCP en todas las OU: no salir de la organización, no apagar los servicios de seguridad, sin usuario raíz, regiones permitidas, protección del estado y de los roles de CI; RCP opcional (perímetro de datos).
- Cuentas con `close_on_deletion = false` y sin acceso de usuarios IAM a la facturación.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
