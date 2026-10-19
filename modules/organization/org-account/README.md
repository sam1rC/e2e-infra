# org-account

Cuenta miembro de AWS Organizations (SaaS T1: `security`, `log-archive`, `control-plane`, `app-*` y una por tenant silo), colocada en su OU para heredar las SCP de `org-guardrails`.

## Uso

```hcl
module "account" {
  source = "../../modules/organization/org-account"

  project     = "acme"
  environment = "prod"
  account_key = "log-archive"
  email       = "aws+acme-log-archive@example.com"
  parent_id   = "ou-abcd-12345678"
}
```

Más opciones en [`examples/complete`](examples/complete). Se aplica desde la **cuenta de management**; la composición de SaaS T1 lo hace en `blueprints/saas-t1/security`.

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
| [aws_organizations_account.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_account) | resource |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_key"></a> [account\_key](#input\_account\_key) | Identificador corto y estable de la cuenta (security, log-archive, app-prod, silo-<tenant>...). Forma el nombre <project>-<account\_key> si name es null. | `string` | n/a | yes |
| <a name="input_close_on_deletion"></a> [close\_on\_deletion](#input\_close\_on\_deletion) | Cierra la cuenta al destruir el recurso. false (por defecto) solo la saca de OpenTofu: cerrar una cuenta borra todo lo que contiene tras 90 días y no se puede deshacer en ese plazo sin soporte. | `bool` | `false` | no |
| <a name="input_email"></a> [email](#input\_email) | Correo raíz de la cuenta: único en AWS, de un buzón o alias del cliente que alguien lea (recuperación del usuario raíz). Cambiarlo después no se puede hacer desde OpenTofu. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno al que pertenece la cuenta (las cuentas compartidas como security o log-archive usan prod). | `string` | n/a | yes |
| <a name="input_iam_user_access_to_billing"></a> [iam\_user\_access\_to\_billing](#input\_iam\_user\_access\_to\_billing) | Permite a usuarios IAM de la cuenta ver la facturación (ALLOW) o no (DENY, por defecto: la facturación se consulta desde la cuenta de management). | `string` | `"DENY"` | no |
| <a name="input_name"></a> [name](#input\_name) | Nombre visible de la cuenta. null = <project>-<account\_key>. | `string` | `null` | no |
| <a name="input_parent_id"></a> [parent\_id](#input\_parent\_id) | OU (ou-...) o raíz (r-...) donde se coloca la cuenta. Las SCP de org-guardrails se heredan de ahí. | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo del nombre de la cuenta si name es null. | `string` | n/a | yes |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | Rol que Organizations crea en la cuenta nueva con AdministratorAccess y confianza en la cuenta de management. Solo para el bootstrap (account-baseline, cross-account-role); después se restringe con SCP y se usa IAM Identity Center. | `string` | `"OrganizationAccountAccessRole"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales de la cuenta (p. ej. Tenant para cuentas silo). | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_account_arn"></a> [account\_arn](#output\_account\_arn) | ARN de la cuenta en la organización. |
| <a name="output_account_id"></a> [account\_id](#output\_account\_id) | ID de la cuenta (12 dígitos): allowed\_account\_ids y assume\_role de las composiciones de live/. |
| <a name="output_account_name"></a> [account\_name](#output\_account\_name) | Nombre de la cuenta. |
| <a name="output_bootstrap_role_arn"></a> [bootstrap\_role\_arn](#output\_bootstrap\_role\_arn) | Rol de administración que crea Organizations en la cuenta (solo bootstrap: account-baseline y roles de despliegue). |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- `close_on_deletion = false` por defecto: destruir el recurso no cierra la cuenta (cerrarla borra lo que contiene tras 90 días). Con `false`, AWS solo permite sacarla de la organización si tiene datos de pago propios: retirar una cuenta es un paso manual del runbook.
- `iam_user_access_to_billing = DENY`: la facturación se consulta desde la cuenta de management.
- `role_name` (por defecto `OrganizationAccountAccessRole`) es solo para el bootstrap (`account-baseline`, roles de despliegue); después el acceso humano va por IAM Identity Center y las SCP de `org-guardrails` acotan lo que puede hacer.
- `lifecycle.ignore_changes` sobre `role_name` e `iam_user_access_to_billing`: Organizations no los devuelve tras crear la cuenta y, sin ignorarlos, cada plan propondría recrearla.
- El correo raíz debe ser un buzón del cliente que alguien lea (recuperación del usuario raíz).

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
