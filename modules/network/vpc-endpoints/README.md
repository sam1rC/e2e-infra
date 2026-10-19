# vpc-endpoints

Endpoints de VPC: gateway para S3 y DynamoDB, e interfaz para los servicios de AWS que usa la capa app, con security group restringido y políticas de endpoint de mínimo alcance.

## Uso

```hcl
module "vpc_endpoints" {
  source = "../../modules/network/vpc-endpoints"

  project         = "acme"
  environment     = "prod"
  vpc_id          = module.vpc.vpc_id
  vpc_cidr_block  = module.vpc.vpc_cidr_block
  subnet_ids      = module.vpc.subnet_ids["app"]
  route_table_ids = concat(module.vpc.route_table_ids["app"], module.vpc.route_table_ids["data"])

  allowed_security_group_ids = {
    app = aws_security_group.app.id
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
| [aws_security_group.interface](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_endpoint.gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.interface](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_security_group_ingress_rule.from_app_security_groups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.from_vpc_cidr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.dynamodb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allowed_security_group_ids"></a> [allowed\_security\_group\_ids](#input\_allowed\_security\_group\_ids) | Security groups de aplicación autorizados a usar los endpoints de interfaz (puerto 443), como mapa nombre estable => ID. Un mapa (y no una lista) permite pasar IDs que aún no existen: las claves son conocidas al planificar. | `map(string)` | `{}` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_gateway_services"></a> [gateway\_services](#input\_gateway\_services) | Servicios con endpoint de tipo gateway (gratuitos). | `list(string)` | <pre>[<br/>  "s3",<br/>  "dynamodb"<br/>]</pre> | no |
| <a name="input_ingress_from_other_layers"></a> [ingress\_from\_other\_layers](#input\_ingress\_from\_other\_layers) | Las reglas de entrada 443 las añaden las capas que consumen los endpoints (data, app), sobre el security group que publica este módulo (security\_group\_id): es el patrón de los blueprints por capas, donde los SG de las tareas y de la rotación aún no existen al desplegar la red (ADR 0016). Solo relaja la validación; no abre nada. | `bool` | `false` | no |
| <a name="input_interface_services"></a> [interface\_services](#input\_interface\_services) | Servicios con endpoint de interfaz (nombre sin el prefijo com.amazonaws.<región>.). Opcionales habituales: ssm, ssmmessages, ec2messages, monitoring, xray (trazas OTLP sin NAT), rds-data, elasticache, events, sqs, sns. | `list(string)` | <pre>[<br/>  "ecr.api",<br/>  "ecr.dkr",<br/>  "logs",<br/>  "secretsmanager",<br/>  "sts",<br/>  "kms"<br/>]</pre> | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_route_table_ids"></a> [route\_table\_ids](#input\_route\_table\_ids) | Tablas de rutas (app y data) a las que se asocian los endpoints de tipo gateway. | `list(string)` | n/a | yes |
| <a name="input_s3_additional_bucket_arns"></a> [s3\_additional\_bucket\_arns](#input\_s3\_additional\_bucket\_arns) | Buckets de S3 de AWS o de terceros (ARN del bucket, sin /*) con acceso de lectura a través del endpoint, además del bucket de capas de ECR de la región. | `list(string)` | `[]` | no |
| <a name="input_s3_allowed_account_ids"></a> [s3\_allowed\_account\_ids](#input\_s3\_allowed\_account\_ids) | Cuentas adicionales cuyos buckets puede alcanzar el endpoint de S3 (la cuenta actual siempre está permitida). | `list(string)` | `[]` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subredes de la capa app (una por AZ, mínimo 2) donde se crean las interfaces de los endpoints. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_vpc_cidr_block"></a> [vpc\_cidr\_block](#input\_vpc\_cidr\_block) | CIDR de la VPC (solo se usa si vpc\_cidr\_fallback = true). | `string` | n/a | yes |
| <a name="input_vpc_cidr_fallback"></a> [vpc\_cidr\_fallback](#input\_vpc\_cidr\_fallback) | Permite además la entrada 443 desde todo el CIDR de la VPC. Es más permisivo: úsalo solo si no puedes enumerar los security groups de aplicación. | `bool` | `false` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID de la VPC donde se crean los endpoints. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_gateway_endpoint_ids"></a> [gateway\_endpoint\_ids](#output\_gateway\_endpoint\_ids) | IDs de los endpoints gateway, por servicio. |
| <a name="output_gateway_endpoint_prefix_list_ids"></a> [gateway\_endpoint\_prefix\_list\_ids](#output\_gateway\_endpoint\_prefix\_list\_ids) | ID de la lista de prefijos de cada endpoint gateway, por servicio: úsala como destino en las reglas de salida de los security groups (p. ej. egress\_rules de ecs-service hacia S3). |
| <a name="output_interface_endpoint_ids"></a> [interface\_endpoint\_ids](#output\_interface\_endpoint\_ids) | IDs de los endpoints de interfaz, por servicio. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID del security group de los endpoints de interfaz. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Gateway (S3 y DynamoDB)**, gratuitos, asociados a las tablas `app` y `data`: la capa `data` puede usar S3 y DynamoDB aunque no tenga ruta a Internet.
- **Interfaz** (por defecto `ecr.api`, `ecr.dkr`, `logs`, `secretsmanager`, `sts`, `kms`) en las subredes `app`, con DNS privado. Opcionales: `ssm`, `ssmmessages`, `monitoring`, `xray` (trazas OTLP a X-Ray sin NAT), `rds-data`, `elasticache`... Cada endpoint de interfaz se cobra por hora y por AZ.
- **Security group propio, sin reglas de salida y con entrada 443 solo desde los security groups indicados** (`allowed_security_group_ids`, un mapa `nombre => ID`; un mapa y no una lista porque los IDs pueden no existir aún al planificar y `for_each` exige claves conocidas). Se rechaza una configuración sin ningún origen.
- **`vpc_cidr_fallback`** (por defecto `false`) permite además 443 desde todo el CIDR de la VPC. Es más permisivo que la regla por security group; el plan lo describe como respaldo, y aquí es explícito en lugar de estar activo por defecto.
- **Política del endpoint de S3:** solo buckets de la cuenta actual (`aws:ResourceAccount`; amplía con `s3_allowed_account_ids`) más lectura del bucket de capas de ECR de la región (`prod-<región>-starport-layer-bucket`), necesario para `docker pull` sin NAT. Cualquier otro bucket (repositorios de paquetes de AWS, datos de terceros) debe añadirse en `s3_additional_bucket_arns`; si no, el acceso desde la VPC falla con `AccessDenied`.
- **Política del endpoint de DynamoDB:** solo tablas de la cuenta y región actuales.
- Los endpoints de interfaz usan la política por defecto de AWS (acceso completo al servicio); la restricción real la imponen IAM y el security group.
- No hay endpoint de interfaz para `s3`: las cargas de la capa `app` usan el gateway.

### Cómo se verificó

- 15 tests unitarios con `mock_provider`.
- **Pendiente en sandbox** (criterio de aceptación de la fase): una tarea en una subred `app` descarga una imagen de ECR sin tráfico por NAT (`BytesOutToDestination` de la NAT ≈ 0). El módulo no se ha planificado contra AWS real porque usa data sources de la cuenta.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
