# data/postgres-app-secret

Secreto **`app_runtime`** de la aplicación para una base PostgreSQL (Aurora o RDS) y, opcionalmente, su **rotación multiusuario** con la función oficial `PostgreSQLMultiUser` de AWS. Es un módulo auxiliar (no figura en el plan original) que `aurora-postgresql` y `rds-postgresql` invocan: así el secreto, la función de rotación y sus reglas de red viven en un solo sitio.

El secreto se crea **vacío**: el rol SQL de aplicación (privilegios mínimos, distinto del maestro) y su credencial inicial los crea el bootstrap SQL de la fase 8.4, fuera de OpenTofu.

## Uso

```hcl
module "app_secret" {
  source = "../../modules/data/postgres-app-secret"

  environment          = "prod"
  name                 = "acme-prod-aurora"
  vpc_id               = module.vpc.vpc_id
  db_security_group_id = aws_security_group.db.id
  kms_key_arn          = module.kms_data.key_arn
  master_secret_arn    = aws_rds_cluster.this.master_user_secret[0].secret_arn

  rotation = {
    subnet_ids                 = module.vpc.subnet_ids["app"]
    endpoint_security_group_id = module.vpc_endpoints.security_group_id
    semantic_version           = "<versión fijada>"
  }
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
| [aws_cloudformation_stack.rotation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack) | resource |
| [aws_cloudwatch_log_group.rotation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_secretsmanager_secret.app_runtime](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.initial](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.rotation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.rotation_to_db](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.rotation_to_secretsmanager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.db_from_rotation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_app_username"></a> [app\_username](#input\_app\_username) | Rol SQL de la aplicación que crea el bootstrap (sql/00-app-runtime.sql). La rotación multiusuario alterna entre <app\_username> y <app\_username>\_clone. | `string` | `"app_runtime"` | no |
| <a name="input_db_host"></a> [db\_host](#input\_db\_host) | Endpoint de la base de datos (writer de Aurora o instancia RDS). Va en la versión inicial del secreto junto con el puerto, la base y el usuario: la rotación multiusuario y la aplicación lo leen de ahí. | `string` | `null` | no |
| <a name="input_db_name"></a> [db\_name](#input\_db\_name) | Base de datos de la aplicación (clave dbname del secreto). | `string` | `"app"` | no |
| <a name="input_db_port"></a> [db\_port](#input\_db\_port) | Puerto de PostgreSQL. | `number` | `5432` | no |
| <a name="input_db_security_group_id"></a> [db\_security\_group\_id](#input\_db\_security\_group\_id) | Security group de la base de datos. El módulo le añade una regla de entrada desde la función de rotación. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN de la CMK que cifra el secreto de la aplicación (y la que cifra el secreto maestro, a la que la función de rotación necesita acceso). | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retención del log group de la función de rotación, en días (valores admitidos por CloudWatch Logs). En prod, al menos 90. | `number` | `90` | no |
| <a name="input_master_secret_arn"></a> [master\_secret\_arn](#input\_master\_secret\_arn) | ARN del secreto maestro gestionado por RDS. Obligatorio si se activa la rotación: la función lo usa para crear/alternar el segundo usuario. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Prefijo de los recursos (p. ej. acme-prod-aurora): el secreto se llama <name>/app\_runtime y la función de rotación <name>-rotation. | `string` | n/a | yes |
| <a name="input_recovery_window_in_days"></a> [recovery\_window\_in\_days](#input\_recovery\_window\_in\_days) | Días de recuperación del secreto tras borrarlo (7-30). 0 = borrado inmediato, solo fuera de prod (sandbox y pruebas de integración: el nombre queda libre al momento). null = 30 en prod y 7 en el resto. | `number` | `null` | no |
| <a name="input_rotation"></a> [rotation](#input\_rotation) | Rotación multiusuario del secreto de la aplicación con la función PostgreSQLMultiUser que genera CloudFormation (HostedRotationLambda). subnet\_ids son subredes con ruta al endpoint de Secrets Manager (capa app) y endpoint\_security\_group\_id el SG del endpoint de interfaz de Secrets Manager. null = sin rotación (no permitido en prod). | <pre>object({<br/>    subnet_ids                 = list(string)<br/>    endpoint_security_group_id = string<br/>    automatically_after_days   = optional(number, 30)<br/>  })</pre> | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC donde se crea el security group de la función de rotación. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_rotation_lambda_arn"></a> [rotation\_lambda\_arn](#output\_rotation\_lambda\_arn) | ARN de la función de rotación; null si no hay rotación. |
| <a name="output_rotation_security_group_id"></a> [rotation\_security\_group\_id](#output\_rotation\_security\_group\_id) | Security group de la función de rotación; null si no hay rotación. |
| <a name="output_secret_arn"></a> [secret\_arn](#output\_secret\_arn) | ARN del secreto de la aplicación (app\_runtime). Las tareas ECS lo leen con `secrets`; el execution role necesita GetSecretValue sobre este ARN y kms:Decrypt vía Secrets Manager. |
| <a name="output_secret_name"></a> [secret\_name](#output\_secret\_name) | Nombre del secreto de la aplicación. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Sin valores sensibles en código ni estado:** OpenTofu crea el contenedor del secreto, no su valor (no hay `aws_secretsmanager_secret_version`). La credencial la escribe el bootstrap SQL y la rota Secrets Manager.
- **Cifrado** con la CMK del entorno (`kms_key_arn`); la política de la clave debe permitir a Secrets Manager (`via_services = ["secretsmanager.<región>.amazonaws.com"]` en `foundation/kms-key`).
- **Rotación multiusuario** (alternancia de dos usuarios): la credencial anterior sigue siendo válida hasta la siguiente rotación, de modo que las tareas con la credencial en caché no fallan durante el cambio. La función es la plantilla oficial de AWS (`SecretsManagerRDSPostgreSQLRotationMultiUser`, Serverless Application Repository), no código propio.
- **`rotate_immediately = false`:** el secreto está vacío hasta el bootstrap y una rotación inmediata fallaría.
- **En prod la rotación es obligatoria** (validación `rotation != null`).
- **Red mínima de la función de rotación:** su SG solo sale hacia el SG de la base (puerto de PostgreSQL) y hacia el SG del endpoint de interfaz de Secrets Manager (443), siempre por referencia de SG. La base de datos añade una única regla de entrada desde ese SG. La función necesita un endpoint de Secrets Manager en la VPC (`vpc-endpoints` con `secretsmanager`) y que el SG de ese endpoint admita a `rotation_security_group_id` (ver ejemplo `complete`).
- **IAM fuera de OpenTofu:** la pila del Serverless Application Repository crea con CloudFormation el rol de la función (`CAPABILITY_IAM`). Es una excepción asumida para no copiar ni mantener código de rotación de AWS; revisa el rol resultante en la primera instalación.
- **Fija `rotation.semantic_version` en producción.** Con `null` se despliega la última versión publicada, que puede cambiar entre ejecuciones. En otras particiones (`aws-cn`, GovCloud) indica `rotation.application_id`.
- **Supuesto sin verificar:** que el secreto maestro gestionado por RDS sirva como `masterSecretArn` de la función multiusuario (AWS documenta que un secreto gestionado por RDS no se rota con una función propia, pero no queda claro que no pueda ser el *superusuario* de otra rotación). Verifícalo en sandbox antes de usar la rotación en producción; si no fuera posible, la alternativa es un secreto de administración propio.

### Cómo se verificó

- 12 tests unitarios con `mock_provider` (borrado inmediato permitido fuera de prod y rechazado en prod, secreto vacío cifrado, rotación desplegada con los parámetros esperados, `rotate_immediately = false`, SG con solo dos reglas de salida y una de entrada en la BD, valores por defecto de prod, y 5 validaciones que deben fallar). Los dos ejemplos validan y su grafo de dependencias es acíclico.
- **Pendiente en sandbox:** instalar la pila de rotación (nombres de los parámetros de la plantilla y salida `RotationLambdaARN` tomados de la documentación de AWS, sin comprobar contra la API), rotar un secreto relleno por el bootstrap y confirmar el supuesto del secreto maestro (ver arriba).

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
