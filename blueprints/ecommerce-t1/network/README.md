# ecommerce-t1 / network

Capa de red de E-commerce T1: VPC, NAT, endpoints de VPC, bucket de logs, CMK de plataforma y topic de alarmas del entorno.

NAT regional (sin subredes públicas) en staging/prod y una NAT zonal en dev (plan 9.2); `xray` entre los endpoints para el sidecar ADOT; DNS Firewall opcional con las listas gestionadas de AWS.

## Uso

Composición de referencia (equivale a `live/<env>/network` de la fase 10): [`../examples/complete/network`](../examples/complete/network).

- **Lee de SSM:** —
- **Publica en SSM:** `vpc_id`, `subnet_ids/*`, `route_table_ids/*` (módulo `vpc`), `kms_key_arn`, `logs_bucket_name|arn`, `endpoints_security_group_id`, `s3_prefix_list_id`, `alarm_topic_arn`, `az_names`.

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
| <a name="module_dns_firewall"></a> [dns\_firewall](#module\_dns\_firewall) | ../../../modules/security/dns-firewall | n/a |
| <a name="module_endpoints"></a> [endpoints](#module\_endpoints) | ../../../modules/network/vpc-endpoints | n/a |
| <a name="module_kms"></a> [kms](#module\_kms) | ../../../modules/foundation/kms-key | n/a |
| <a name="module_logs"></a> [logs](#module\_logs) | ../../../modules/storage/s3-bucket | n/a |
| <a name="module_notifications"></a> [notifications](#module\_notifications) | ../../../modules/observability/alarms | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../../../modules/network/vpc | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ssm_parameter.layer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_elb_service_account.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/elb_service_account) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alarm_emails"></a> [alarm\_emails](#input\_alarm\_emails) | Correos suscritos al topic de alarmas del entorno (lo comparten todas las capas). Deben confirmar la suscripción. En prod, al menos uno. | `list(string)` | `[]` | no |
| <a name="input_az_names"></a> [az\_names](#input\_az\_names) | Zonas de disponibilidad (2 o 3), explícitas. El ALB exige al menos 2; Fargate en 2 AZ no cuesta más. | `list(string)` | n/a | yes |
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | CIDR de la VPC (entre /16 y /20). Reserva rangos distintos por entorno si algún día se interconectan. | `string` | `"10.10.0.0/16"` | no |
| <a name="input_dns_firewall_lists"></a> [dns\_firewall\_lists](#input\_dns\_firewall\_lists) | Listas gestionadas de DNS Firewall (opcional en T1), por clave estable: domain\_list\_id (cambia por región; ver security/dns-firewall), priority única, action (BLOCK por defecto) y block\_response. Vacío = sin DNS Firewall. Los logs de consultas van al bucket de logs (prefijo dns/). | <pre>map(object({<br/>    domain_list_id = string<br/>    priority       = number<br/>    action         = optional(string, "BLOCK")<br/>    block_response = optional(string, "NXDOMAIN")<br/>  }))</pre> | `{}` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_interface_endpoints"></a> [interface\_endpoints](#input\_interface\_endpoints) | Servicios con endpoint de interfaz (cada uno cuesta ~0,01 USD/h por AZ). Los de por defecto permiten descargar imágenes de ECR, escribir logs, leer secretos, rotarlos y enviar trazas OTLP del sidecar ADOT (xray) sin pasar por la NAT. | `list(string)` | <pre>[<br/>  "ecr.api",<br/>  "ecr.dkr",<br/>  "logs",<br/>  "secretsmanager",<br/>  "sts",<br/>  "kms",<br/>  "xray"<br/>]</pre> | no |
| <a name="input_nat_mode"></a> [nat\_mode](#input\_nat\_mode) | Salida a Internet de la capa app. null = zonal\_single en dev y regional en staging/prod (plan 9.2). La NAT regional no necesita subredes públicas. | `string` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto (cliente); prefijo de los nombres de recursos y de las rutas SSM. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales para los recursos (las obligatorias van en default\_tags del provider, en live/). | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alarm_topic_arn"></a> [alarm\_topic\_arn](#output\_alarm\_topic\_arn) | Topic SNS de alarmas del entorno, compartido por todas las capas. |
| <a name="output_endpoints_security_group_id"></a> [endpoints\_security\_group\_id](#output\_endpoints\_security\_group\_id) | Security group de los endpoints de interfaz (las capas consumidoras le añaden su regla 443). |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | CMK de plataforma del entorno. |
| <a name="output_logs_bucket_name"></a> [logs\_bucket\_name](#output\_logs\_bucket\_name) | Bucket de flow logs y logs de acceso del ALB. |
| <a name="output_nat_gateway_ids"></a> [nat\_gateway\_ids](#output\_nat\_gateway\_ids) | NAT por clave (AZ). |
| <a name="output_nat_mode"></a> [nat\_mode](#output\_nat\_mode) | Modo de NAT aplicado (según el entorno si nat\_mode es null). |
| <a name="output_ssm_prefix"></a> [ssm\_prefix](#output\_ssm\_prefix) | Prefijo SSM con las salidas de la capa (ADR 0004). |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | Subredes por capa (public, app, data), en el orden de az\_names. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID de la VPC. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- VPC con subredes `app` y `data` privadas; `data` sin ruta a Internet y con NACL que solo admite los puertos de datos desde `app` (módulo `network/vpc`).
- Endpoints de VPC (ECR, logs, Secrets Manager, STS, KMS, X-Ray) y gateways de S3/DynamoDB: las tareas descargan imágenes y leen secretos sin salir por la NAT. El SG de los endpoints no tiene reglas propias: cada capa consumidora añade su entrada 443 desde su SG (ADR 0016).
- Flow logs a un bucket SSE-S3 propio con política que solo admite `delivery.logs.amazonaws.com` y el servicio de logs del ALB de la región, con `aws:SourceAccount`.
- CMK `platform` con rotación (logs, SNS, ECR, bus): `deletion_window_in_days` 30 en prod.
- Topic de alarmas cifrado con la CMK, con política que deniega el transporte sin TLS; es el destino de las alarmas de NAT, de AWS Backup y de la capa `app`.
- DNS Firewall (opcional): bloquea dominios de malware/botnets/amenazas con `NXDOMAIN` y registra las consultas en el bucket de logs (`dns/`).

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
