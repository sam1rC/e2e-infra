# compute/ecs-cluster

Cluster **ECS** para Fargate con Container Insights enhanced, capacity providers FARGATE/FARGATE_SPOT (Spot solo fuera de prod por defecto) y ECS Exec opcional con registro de sesiones cifrado.

## Uso

```hcl
module "cluster" {
  source = "../../modules/compute/ecs-cluster"

  project     = "acme"
  environment = "prod"
  kms_key_arn = module.kms_logs.key_arn # su política debe autorizar a logs.<región>.amazonaws.com
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
| [aws_cloudwatch_log_group.container_insights](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_container_insights"></a> [container\_insights](#input\_container\_insights) | Container Insights del cluster: enhanced (métricas a nivel de tarea y contenedor), enabled o disabled (no admitido en prod). | `string` | `"enhanced"` | no |
| <a name="input_enable_exec"></a> [enable\_exec](#input\_enable\_exec) | Configura ECS Exec con registro de sesiones cifrado (log group con CMK). null = true en dev/staging y false en prod. Los servicios deben activar enable\_execute\_command por su cuenta. | `bool` | `null` | no |
| <a name="input_enable_fargate_spot"></a> [enable\_fargate\_spot](#input\_enable\_fargate\_spot) | Añade FARGATE\_SPOT como capacity provider. null = true en dev/staging y false en prod (las tareas Spot pueden interrumpirse con 2 minutos de aviso). | `bool` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_ephemeral_storage_kms_key_arn"></a> [ephemeral\_storage\_kms\_key\_arn](#input\_ephemeral\_storage\_kms\_key\_arn) | CMK para cifrar el almacenamiento efímero de las tareas Fargate (managed\_storage\_configuration). null = cifrado gestionado por AWS. La política de la clave debe autorizar a Fargate (ver la documentación de ECS). | `string` | `null` | no |
| <a name="input_fargate_spot_weight"></a> [fargate\_spot\_weight](#input\_fargate\_spot\_weight) | Peso de FARGATE\_SPOT frente a FARGATE (peso 1, base 1) en la estrategia por defecto, cuando Spot está activo. | `number` | `3` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN de la CMK que cifra el log group de ECS Exec y, si se indica, el almacenamiento efímero de Fargate. La política de la clave debe autorizar a logs.<región>.amazonaws.com. | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retención de los log groups de ECS Exec y de Container Insights, en días (valores admitidos por CloudWatch Logs). En prod, al menos 90. | `number` | `90` | no |
| <a name="input_name"></a> [name](#input\_name) | Nombre del cluster. Si es null: <project>-<environment>. | `string` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_capacity_providers"></a> [capacity\_providers](#output\_capacity\_providers) | Capacity providers habilitados (FARGATE y, fuera de prod, FARGATE\_SPOT). |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ARN del cluster. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Nombre del cluster. |
| <a name="output_exec_enabled"></a> [exec\_enabled](#output\_exec\_enabled) | true si el cluster tiene ECS Exec configurado con registro cifrado. |
| <a name="output_exec_log_group_name"></a> [exec\_log\_group\_name](#output\_exec\_log\_group\_name) | Nombre del log group de las sesiones de ECS Exec (null si ECS Exec está desactivado). |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Container Insights `enhanced`** por defecto (métricas por tarea y contenedor, base de las alarmas y del dashboard de fases posteriores).
- **Capacity providers:** `FARGATE` siempre, con base 1 en la estrategia por defecto; `FARGATE_SPOT` solo en `dev`/`staging` por defecto (`enable_fargate_spot = null` ⇒ `environment != "prod"`), con peso `fargate_spot_weight`. Las tareas Spot pueden interrumpirse con 2 minutos de aviso, así que en `prod` hay que pedirlo explícitamente.
- **ECS Exec desactivado en `prod` por defecto** (`enable_exec = null` ⇒ `environment != "prod"`). Cuando está activo, las sesiones se registran en un log group **cifrado con la CMK** (`/aws/ecs/<cluster>/exec`, `logging = "OVERRIDE"`, `cloud_watch_encryption_enabled = true`) con retención configurable (mínimo 90 días en prod, validado). Este módulo solo prepara el registro: cada servicio decide si activa `enable_execute_command`.
- **Clave KMS:** la política de la clave debe autorizar a `logs.<región>.amazonaws.com` (`service_principals` de `foundation/kms-key`); si no, el log group no se puede crear.
- **Almacenamiento efímero de Fargate** con CMK propia (`ephemeral_storage_kms_key_arn`, opcional): sin ella se usa el cifrado gestionado por AWS. La política de esa clave debe autorizar a Fargate según la documentación de ECS (no verificado en sandbox).

### Cómo se verificó

- 13 tests unitarios con `mock_provider` (Container Insights, ECS Exec con log group cifrado, estrategia de capacity providers, valores por defecto por entorno y su anulación explícita, almacenamiento efímero y 4 validaciones que deben fallar). Los dos ejemplos validan.
- **Pendiente en sandbox:** crear el cluster con la clave del ejemplo (el log group exige la política de CloudWatch Logs) y, con `ephemeral_storage_kms_key_arn`, comprobar la política que exige Fargate.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
