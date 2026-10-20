# vpc

VPC con subredes por capa (public, app, data) y salida a Internet configurable (NAT regional, zonal o ninguna), NACL de datos, security group por defecto cerrado, flow logs y publicación de IDs en SSM.

## Uso

```hcl
module "vpc" {
  source = "../../modules/network/vpc"

  project     = "acme"
  environment = "prod"
  cidr_block  = "10.20.0.0/16"
  az_names    = ["us-east-1a", "us-east-1b"]

  flow_logs = {
    s3_bucket_arn = module.logs.bucket_arn
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
| [aws_cloudwatch_metric_alarm.nat_port_allocation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_default_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_flow_log.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_nat_gateway.zonal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_network_acl.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl) | resource |
| [aws_network_acl_rule.data_egress_internal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.data_egress_to_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.data_ingress_from_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_network_acl_rule.data_ingress_internal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule) | resource |
| [aws_route.app_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_ssm_parameter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_subnet.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alarm_actions"></a> [alarm\_actions](#input\_alarm\_actions) | ARNs (p. ej. tópico SNS) notificados por la alarma ErrorPortAllocation de la NAT. | `list(string)` | `[]` | no |
| <a name="input_az_names"></a> [az\_names](#input\_az\_names) | Zonas de disponibilidad (2 o 3), explícitas para que las claves de for\_each sean estables. El CIDR de cada subred depende de la posición de su AZ: añade o quita AZ solo por el final de la lista. | `list(string)` | n/a | yes |
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | CIDR IPv4 de la VPC (entre /16 y /20). | `string` | n/a | yes |
| <a name="input_create_internet_gateway"></a> [create\_internet\_gateway](#input\_create\_internet\_gateway) | Crea y asocia un Internet Gateway. Es obligatorio con NAT regional o subredes públicas y lo exigen los VPC origins de CloudFront aunque no haya subredes públicas. | `bool` | `true` | no |
| <a name="input_data_subnet_internet_route"></a> [data\_subnet\_internet\_route](#input\_data\_subnet\_internet\_route) | Solo documenta la decisión de diseño: las subredes data nunca tienen ruta por defecto a Internet. Debe ser false. | `bool` | `false` | no |
| <a name="input_data_tier_ports"></a> [data\_tier\_ports](#input\_data\_tier\_ports) | Puertos TCP que la NACL de la capa data admite desde las subredes app (PostgreSQL y Valkey por defecto). | `list(number)` | <pre>[<br/>  5432,<br/>  6379<br/>]</pre> | no |
| <a name="input_enable_flow_logs"></a> [enable\_flow\_logs](#input\_enable\_flow\_logs) | Activa los VPC Flow Logs hacia S3. Desactívalo solo de forma explícita (p. ej. dev efímero). | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_flow_logs"></a> [flow\_logs](#input\_flow\_logs) | Destino y formato de los flow logs. El bucket (con SSE-KMS) debe permitir la entrega de delivery.logs.amazonaws.com. Obligatorio si enable\_flow\_logs = true. | <pre>object({<br/>    s3_bucket_arn            = string<br/>    traffic_type             = optional(string, "ALL")<br/>    max_aggregation_interval = optional(number, 600)<br/>    log_format               = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_nat_mode"></a> [nat\_mode](#input\_nat\_mode) | Salida a Internet de la capa app: none, zonal\_single (una NAT), zonal\_per\_az (una por AZ) o regional (una NAT regional, sin subredes públicas). | `string` | `"regional"` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_publish_ssm_parameters"></a> [publish\_ssm\_parameters](#input\_publish\_ssm\_parameters) | Publica los IDs de la red en SSM Parameter Store bajo /<project>/<env>/network/ para las capas consumidoras. | `bool` | `true` | no |
| <a name="input_subnet_newbits"></a> [subnet\_newbits](#input\_subnet\_newbits) | Bits adicionales sobre el CIDR de la VPC para calcular cada subred con cidrsubnet (4 sobre un /16 da subredes /20). | `number` | `4` | no |
| <a name="input_subnet_tiers"></a> [subnet\_tiers](#input\_subnet\_tiers) | Capas de subredes a crear. La capa public solo se necesita para NAT zonal; con NAT regional o sin NAT no hace falta. | <pre>object({<br/>    public = optional(bool, false)<br/>    app    = optional(bool, true)<br/>    data   = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_availability_zones"></a> [availability\_zones](#output\_availability\_zones) | Zonas de disponibilidad usadas, en el orden recibido. |
| <a name="output_internet_gateway_id"></a> [internet\_gateway\_id](#output\_internet\_gateway\_id) | ID del Internet Gateway (null si no se crea). |
| <a name="output_nat_gateway_ids"></a> [nat\_gateway\_ids](#output\_nat\_gateway\_ids) | IDs de NAT por clave: nombre de AZ (zonales) o 'regional'. |
| <a name="output_route_table_ids"></a> [route\_table\_ids](#output\_route\_table\_ids) | IDs de tablas de rutas por capa (public: una; app y data: una por AZ en el orden de az\_names). |
| <a name="output_subnet_cidr_blocks"></a> [subnet\_cidr\_blocks](#output\_subnet\_cidr\_blocks) | CIDR de cada subred, por capa y nombre de AZ (solo capas activadas). |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | IDs de subred por capa (public, app, data), ordenados según az\_names. Las capas desactivadas quedan vacías. |
| <a name="output_subnet_ids_by_az"></a> [subnet\_ids\_by\_az](#output\_subnet\_ids\_by\_az) | IDs de subred por capa y nombre de AZ. |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | CIDR de la VPC. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID de la VPC. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Tres capas:** `public` (opcional), `app` y `data`. Las subredes de `data` **nunca** tienen ruta por defecto: solo la local y los endpoints de tipo gateway (S3, DynamoDB) que añade `vpc-endpoints`. `data_subnet_internet_route` existe solo para documentarlo y no admite `true`.
- **NAT:** `regional` (por defecto, sin subredes públicas, en modo automático: AWS la extiende a las AZ con ENI y asigna las EIP), `zonal_single`, `zonal_per_az` o `none`. Con NAT zonal la capa `public` es obligatoria; la NAT regional y los VPC origins de CloudFront necesitan el Internet Gateway (`create_internet_gateway = true`). Pasar de modo automático a manual en la NAT regional recrea el recurso; por eso solo se ofrece el automático.
- **Alarma `ErrorPortAllocation > 0`** por cada NAT, incluida en este módulo (la NAT regional escala de forma reactiva). `observability/alarms` no la duplica. Si el error aparece de forma sostenida, pasa a `zonal_per_az`.
- **Security group por defecto cerrado** (control EC2.2) y `map_public_ip_on_launch = false` en las subredes públicas.
- **NACL de la capa `data`** (sin estado): solo admite TCP desde las subredes `app` a los puertos de `data_tier_ports` (5432 y 6379), el tráfico interno de la capa (réplicas) y las respuestas efímeras (1024-65535) hacia `app`. Las NACL de las demás capas se dejan por defecto; los security groups acotan el tráfico. Si añades un servicio en `data` que necesite otro origen (p. ej. una herramienta de administración) tendrás que ampliar la NACL.
- **Flow logs** a S3 con tráfico `ALL` y formato extendido (incluye `pkt-src-aws-service`, `flow-direction`, `traffic-path`...). Están activos por defecto y exigen indicar el bucket: se desactivan solo con `enable_flow_logs = false`. El bucket debe autorizar a `delivery.logs.amazonaws.com` (ver `examples/complete`). El bucket de logs de `account-baseline` **no** incluye esa autorización: decídelo al componer el blueprint (bucket propio o ampliar su política).
- **Direcciones estables:** subredes, tablas de rutas, NAT y EIP usan `for_each` con el nombre de la AZ. Los CIDR salen de `cidrsubnet(cidr, newbits, offset_capa + posición_de_la_AZ)` con desplazamientos fijos (public 0, app 4, data 8): añadir o quitar una AZ **por el final** de `az_names` no toca las demás. Quitar una AZ intermedia renumera las que le siguen.
- **Publicación en SSM** (`/<project>/<env>/network/…`): `vpc_id`, `vpc_cidr`, `subnet_ids/<capa>` y `route_table_ids/<capa>` (listas separadas por comas, en el orden de `az_names`). Son la interfaz entre capas (ADR 0004); sin secretos.

### Cómo se verificó

- 29 tests unitarios con `mock_provider`. El mock reutiliza el mismo ID en todas las instancias de un recurso, así que no puede comprobar *qué* NAT usa cada AZ ni que ninguna ruta apunta a una tabla `data`.
- Eso se verificó con `tofu plan` real sin credenciales (el módulo no usa data sources) para los cuatro modos de NAT: el provider 6.67.0 acepta la NAT regional automática, los recuentos son los esperados y `aws_route.app_default` solo referencia `aws_route_table.app`.
- **Pendiente:** crear la VPC y la NAT regional en la cuenta sandbox (`tests/integration.tftest.hcl`), incluida la dimensión `NatGatewayId` de la alarma para NAT regionales y el funcionamiento real de la NACL.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
