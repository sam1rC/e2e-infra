# compute/ecr-repository

Repositorio **ECR** privado con etiquetas inmutables, cifrado con CMK, escaneo de vulnerabilidades, ciclo de vida (últimas N imágenes y sin etiqueta a los 7 días) y política opcional para roles de CI.

## Uso

```hcl
module "ecr" {
  source = "../../modules/compute/ecr-repository"

  project     = "acme"
  environment = "prod"
  name        = "web"
  kms_key_arn = module.kms_ecr.key_arn

  keep_last_images  = 30
  ci_principal_arns = ["arn:aws:iam::111111111111:role/gha-push-images"]
}

# La imagen se referencia por digest, nunca por etiqueta:
#   image = "${module.ecr.repository_url}@sha256:..."
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
| [aws_ecr_lifecycle_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_lifecycle_policy) | resource |
| [aws_ecr_registry_scanning_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_registry_scanning_configuration) | resource |
| [aws_ecr_repository.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_ecr_repository_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository_policy) | resource |
| [aws_iam_policy_document.repository](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_ci_principal_arns"></a> [ci\_principal\_arns](#input\_ci\_principal\_arns) | ARNs de roles IAM (p. ej. el rol de CI de otra cuenta) que pueden subir y descargar imágenes. Vacío = sin política de repositorio (solo la cuenta propietaria, por IAM). | `list(string)` | `[]` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_force_delete"></a> [force\_delete](#input\_force\_delete) | Permite borrar el repositorio aunque contenga imágenes. Solo para entornos efímeros: por defecto false. | `bool` | `false` | no |
| <a name="input_keep_last_images"></a> [keep\_last\_images](#input\_keep\_last\_images) | Número de imágenes a conservar; las más antiguas se expiran. | `number` | `30` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN de la CMK que cifra las imágenes del repositorio (obligatorio: no se usa el cifrado AES256 por defecto). | `string` | n/a | yes |
| <a name="input_manage_registry_scanning"></a> [manage\_registry\_scanning](#input\_manage\_registry\_scanning) | Crea la configuración de escaneo del REGISTRO (enhanced, continuo, para los repositorios <project>-<environment>-*). Es un recurso único por cuenta y región: actívalo en una sola instancia del módulo. Solo aplica con scan\_type = enhanced. | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | Nombre de la aplicación/imagen; el repositorio se llama <project>-<environment>-<name>. | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_pull_principal_arns"></a> [pull\_principal\_arns](#input\_pull\_principal\_arns) | ARNs de roles IAM que solo pueden descargar imágenes (p. ej. roles de ejecución de ECS de otras cuentas). | `list(string)` | `[]` | no |
| <a name="input_scan_type"></a> [scan\_type](#input\_scan\_type) | Escaneo de vulnerabilidades: basic (escaneo básico al subir la imagen) o enhanced (Amazon Inspector, continuo; requiere Inspector v2 para ECR, que activa account-baseline). | `string` | `"basic"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_untagged_expiry_days"></a> [untagged\_expiry\_days](#input\_untagged\_expiry\_days) | Días tras los que se borran las imágenes sin etiqueta. | `number` | `7` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_registry_id"></a> [registry\_id](#output\_registry\_id) | ID del registro (cuenta propietaria). |
| <a name="output_repository_arn"></a> [repository\_arn](#output\_repository\_arn) | ARN del repositorio (para políticas IAM de pull/push). |
| <a name="output_repository_name"></a> [repository\_name](#output\_repository\_name) | Nombre del repositorio. |
| <a name="output_repository_url"></a> [repository\_url](#output\_repository\_url) | URL del repositorio (<cuenta>.dkr.ecr.<región>.amazonaws.com/<nombre>). La imagen se referencia por digest: <url>@sha256:... |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Etiquetas inmutables** (`IMMUTABLE`): una etiqueta publicada no se puede sobrescribir, así lo que se despliega es lo que se escaneó. Los servicios referencian la imagen por **digest** (`repo@sha256:...`).
- **Cifrado con CMK** (`kms_key_arn`, obligatorio; no se acepta un alias): no se usa el AES256 por defecto. ECR crea *grants* de KMS en nombre del llamante, por lo que el rol que crea el repositorio necesita `kms:CreateGrant`; quien hace push o pull no necesita permisos de KMS.
- **Escaneo:** `scan_type = "basic"` escanea al subir; `"enhanced"` delega en Amazon Inspector (continuo; `account-baseline` lo activa para ECR). La configuración del **registro** es un recurso único por cuenta y región, por eso solo se gestiona con `manage_registry_scanning = true` y en **una** instancia del módulo.
- **Ciclo de vida:** las imágenes sin etiqueta se borran a los 7 días (`untagged_expiry_days`) y se conservan las últimas `keep_last_images`. La regla `any` va con la prioridad más alta para evaluarse la última.
- **Política de repositorio opcional, mínima:** solo con `ci_principal_arns` (subir y bajar) o `pull_principal_arns` (solo bajar). Acepta **únicamente ARNs de roles IAM** (nunca `:root`, usuarios ni `*`), con acciones explícitas y **sin elemento `Resource`** (el recurso es el propio repositorio; ECR rechaza la política si lo incluye: comprobado contra AWS el 2026-10-06).
- **`force_delete = false`:** un repositorio con imágenes no se destruye por accidente.

### Cómo se verificó

- 11 tests unitarios con `mock_provider` (inmutabilidad, KMS, escaneo, registro opt-in, política de ciclo de vida y su orden, política de repositorio con principales concretos y 4 validaciones que deben fallar). Los dos ejemplos validan.
- **Pendiente en sandbox:** un segundo push con la misma etiqueta es rechazado, el escaneo Inspector produce hallazgos y una tarea Fargate en subredes sin NAT descarga la imagen a través de los endpoints de ECR y el gateway de S3.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
