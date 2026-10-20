# github-oidc

Federación OIDC de GitHub Actions con AWS (sin access keys) y dos roles por entorno:

| Rol | Quién lo asume (`sub`) | Permisos |
|---|---|---|
| `gha-plan-<env>` | `repo:<org>/<repo>:pull_request` y `repo:<org>/<repo>:ref:refs/heads/<main>` | `ReadOnlyAccess` + lectura/escritura del prefijo `<env>/` del estado + uso de la CMK de estado |
| `gha-apply-<env>` | **solo** `repo:<org>/<repo>:environment:<env>` | Políticas de despliegue acotadas por una *permission boundary* + estado |

## Uso

```hcl
module "github_oidc" {
  source = "../../modules/foundation/github-oidc"

  project     = "acme"
  environment = "prod"

  github_org  = "acme-corp"
  github_repo = "acme-infra"

  state_bucket_arn  = module.state_backend.bucket_arn
  state_kms_key_arn = module.state_backend.kms_key_arn
}
```

En el workflow, el job de apply debe declarar `environment: prod` (la aprobación manual se configura en GitHub, en el Environment) y `permissions: { id-token: write, contents: read }`.

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
| [aws_iam_openid_connect_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_policy.apply_boundary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.state_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.apply_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.apply_state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.plan_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.plan_state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_openid_connect_provider.existing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_policy_document.apply_boundary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.apply_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.plan_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.state_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_apply_policy_arns"></a> [apply\_policy\_arns](#input\_apply\_policy\_arns) | Políticas gestionadas del rol de apply. Por defecto AdministratorAccess, acotado por la permission boundary; en producción conviene sustituirlas por una política a medida de lo que despliega el entorno. | `list(string)` | <pre>[<br/>  "arn:aws:iam::aws:policy/AdministratorAccess"<br/>]</pre> | no |
| <a name="input_create_provider"></a> [create\_provider](#input\_create\_provider) | Crea el proveedor OIDC de GitHub. Ponlo en false si la cuenta ya tiene uno (solo puede haber uno por URL). | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. Determina el nombre de los roles, el prefijo de estado y el GitHub Environment que puede asumir el rol de apply. | `string` | n/a | yes |
| <a name="input_github_environment"></a> [github\_environment](#input\_github\_environment) | Nombre del GitHub Environment que autoriza el apply. Si es null se usa el valor de environment. | `string` | `null` | no |
| <a name="input_github_org"></a> [github\_org](#input\_github\_org) | Organización (o usuario) de GitHub propietaria del repositorio. | `string` | n/a | yes |
| <a name="input_github_repo"></a> [github\_repo](#input\_github\_repo) | Nombre del repositorio de GitHub (sin la organización). | `string` | n/a | yes |
| <a name="input_github_subject_prefix"></a> [github\_subject\_prefix](#input\_github\_subject\_prefix) | Prefijo del claim sub del token OIDC de GitHub tal como lo emite el repositorio: sub\_claim\_prefix de `gh api repos/<org>/<repo>/actions/oidc/customization/sub`. Los repositorios nuevos usan el formato inmutable repo:<org>@<id>/<repo>@<id> (resiste renombrados y recreaciones del repositorio). null = formato clásico repo:<github\_org>/<github\_repo>. | `string` | `null` | no |
| <a name="input_main_branch"></a> [main\_branch](#input\_main\_branch) | Rama principal desde la que el rol de plan puede ejecutarse además de los pull requests. | `string` | `"main"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefijo de los nombres de rol: <prefix>-plan-<env> y <prefix>-apply-<env>. | `string` | `"gha"` | no |
| <a name="input_plan_policy_arns"></a> [plan\_policy\_arns](#input\_plan\_policy\_arns) | Políticas gestionadas del rol de plan (solo lectura). Por defecto ReadOnlyAccess. | `list(string)` | <pre>[<br/>  "arn:aws:iam::aws:policy/ReadOnlyAccess"<br/>]</pre> | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_state_bucket_arn"></a> [state\_bucket\_arn](#input\_state\_bucket\_arn) | ARN del bucket de estado (salida de state-backend). | `string` | n/a | yes |
| <a name="input_state_kms_key_arn"></a> [state\_kms\_key\_arn](#input\_state\_kms\_key\_arn) | ARN de la CMK de estado (salida de state-backend). | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_apply_boundary_policy_arn"></a> [apply\_boundary\_policy\_arn](#output\_apply\_boundary\_policy\_arn) | ARN de la permission boundary del rol de apply. |
| <a name="output_apply_role_arn"></a> [apply\_role\_arn](#output\_apply\_role\_arn) | ARN del rol de apply (usar solo en jobs con environment: <env>). |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN del proveedor OIDC de GitHub usado por los roles. |
| <a name="output_plan_role_arn"></a> [plan\_role\_arn](#output\_plan\_role\_arn) | ARN del rol de plan (usar en configure-aws-credentials de los jobs de plan). |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- Las trust policies exigen `aud = sts.amazonaws.com` y comparan `sub` con `StringEquals` (nunca `StringLike`); los inputs `github_org`/`github_repo` se validan contra comodines.
- El rol de apply no puede asumirse desde una rama ni un pull request, aunque se modifique el workflow: el `sub` solo existe en jobs que despliegan al GitHub Environment. **Configura en GitHub las reglas del Environment** (revisores obligatorios en `prod` y restricción de ramas desplegables a `main`); sin ellas, cualquier rama podría declarar `environment: prod`.
- La *permission boundary* del rol de apply (techo de permisos) deniega:
  - modificar los propios roles, la boundary, la política de acceso al estado o el proveedor OIDC;
  - desactivar CloudTrail, GuardDuty, Security Hub, Config o Access Analyzer;
  - crear usuarios IAM, access keys, perfiles de login o credenciales de servicio;
  - cambiar la configuración del bucket de estado, borrar versiones del estado o destruir/deshabilitar su CMK.
- `max_session_duration = 3600`.
- Los ARN protegidos se construyen por nombre, no por referencia, para evitar un ciclo de dependencias entre los roles y la boundary que los protege.

### Límites conocidos

- La boundary **no impide** que el rol de apply cree otros roles (sin boundary) y los asuma: eso lo cubren las SCP de `org-guardrails`. Con una cuenta sin SCP, restringe `apply_policy_arns` a lo que realmente despliega el entorno en lugar de usar `AdministratorAccess`.
- `ReadOnlyAccess` es amplio; si tu política de datos lo exige, sustitúyelo en `plan_policy_arns`.
- Cambios al módulo `state-backend` o a este módulo, y la destrucción de la línea base de seguridad, requieren credenciales de bootstrap/*break-glass*, no el rol de apply.
- Solo puede existir un proveedor OIDC de GitHub por cuenta: usa `create_provider = false` si ya existe.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
