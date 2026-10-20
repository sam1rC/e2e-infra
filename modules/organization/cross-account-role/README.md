# cross-account-role

Rol IAM asumible desde otras cuentas: despliegue en las cuentas silo desde el CI del control plane (SaaS T1) y acceso de soporte del proveedor, revocable borrando el rol (runbook `revoke-provider-access`).

## Uso

```hcl
module "deploy_role" {
  source = "../../modules/organization/cross-account-role"

  project           = "acme"
  environment       = "prod"
  name              = "silo-deploy"
  trusted_role_arns = ["arn:aws:iam::111111111111:role/gha-apply-prod"]

  managed_policy_arns = {
    admin = "arn:aws:iam::aws:policy/AdministratorAccess"
  }
  permissions_boundary_arn = "arn:aws:iam::222222222222:policy/acme-deploy-boundary"
}
```

Acceso de un tercero con `external_id`, MFA y solo lectura: [`examples/complete`](examples/complete).

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
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allow_tag_session"></a> [allow\_tag\_session](#input\_allow\_tag\_session) | Permite sts:TagSession (etiquetas de sesión para ABAC o trazabilidad en CloudTrail). | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_external_id"></a> [external\_id](#input\_external\_id) | ExternalId exigido en AssumeRole (sts:ExternalId): obligatorio cuando quien asume es un tercero (el proveedor) para evitar el confused deputy. No es un secreto, pero tampoco se publica. null = sin ExternalId (roles entre cuentas del propio cliente). | `string` | `null` | no |
| <a name="input_inline_policies"></a> [inline\_policies](#input\_inline\_policies) | Políticas JSON en línea, por nombre estable, con acciones y recursos explícitos. | `map(string)` | `{}` | no |
| <a name="input_managed_policy_arns"></a> [managed\_policy\_arns](#input\_managed\_policy\_arns) | Políticas gestionadas adjuntas, por clave estable (p. ej. readonly = arn:aws:iam::aws:policy/ReadOnlyAccess). Un mapa para que quitar una no afecte a las demás. | `map(string)` | `{}` | no |
| <a name="input_max_session_duration"></a> [max\_session\_duration](#input\_max\_session\_duration) | Duración máxima de la sesión, en segundos (3600-43200). 1 hora por defecto. | `number` | `3600` | no |
| <a name="input_name"></a> [name](#input\_name) | Nombre lógico del rol; el real es <project>-<environment>-<name> (p. ej. silo-deploy, provider-access). | `string` | n/a | yes |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | Si se indica, solo pueden asumir el rol principals de esta organización (aws:PrincipalOrgID), además de estar en trusted\_role\_arns. Úsalo entre cuentas del cliente; nunca para el proveedor. | `string` | `null` | no |
| <a name="input_permissions_boundary_arn"></a> [permissions\_boundary\_arn](#input\_permissions\_boundary\_arn) | Permissions boundary del rol: obligatoria si el rol puede crear o modificar roles IAM (p. ej. un rol de despliegue), para que no pueda escalar privilegios. | `string` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo del nombre del rol. | `string` | n/a | yes |
| <a name="input_require_mfa"></a> [require\_mfa](#input\_require\_mfa) | Exige MFA en la sesión de quien asume el rol (aws:MultiFactorAuthPresent). Para accesos humanos (soporte del proveedor); no lo actives para roles de CI, que no tienen MFA. | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_trusted_role_arns"></a> [trusted\_role\_arns](#input\_trusted\_role\_arns) | Roles IAM de OTRAS cuentas que pueden asumir este rol (p. ej. el rol de apply de CI del control plane, o el rol de soporte del proveedor). Solo roles concretos: nunca la raíz de una cuenta, usuarios ni comodines. | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_assume_role_policy_json"></a> [assume\_role\_policy\_json](#output\_assume\_role\_policy\_json) | Trust policy del rol (para revisión y auditoría). |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN del rol (role\_arn del assume\_role del provider en la cuenta de origen). |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Nombre del rol. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- Solo confía en **roles concretos** (`trusted_role_arns`): la validación rechaza la raíz de una cuenta, usuarios y comodines.
- `external_id` (`sts:ExternalId`) para terceros, contra el *confused deputy*; `organization_id` (`aws:PrincipalOrgID`) para limitar a la organización del cliente; `require_mfa` para accesos humanos.
- Sesiones de 1 hora por defecto (máximo 12).
- Al menos una política explícita; si el rol puede crear roles IAM (despliegue), usa `permissions_boundary_arn` para que no pueda escalar privilegios.
- Políticas gestionadas por clave estable (`for_each`): quitar una no toca las demás.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
