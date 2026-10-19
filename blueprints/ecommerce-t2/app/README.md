# ecommerce-t2 / app

Capa de aplicación de E-commerce T2: ECR, cluster ECS, ALB interno con el certificado regional del dominio público, servicio Fargate, alarmas y dashboard.

El servicio recibe por variables de entorno el endpoint de PostgreSQL; las credenciales de `app_runtime` se inyectan desde Secrets Manager.

## Uso

Composición de referencia (equivale a `live/<env>/app` de la fase 10): [`../examples/complete/app`](../examples/complete/app).

- **Lee de SSM:** `network` y `data`.
- **Publica en SSM:** `alb_arn`, `alb_dns_name`, `alb_security_group_id`, `service_security_group_id`, `task_role_arn`, `ecr_repository_url`, `cluster_name`, `service_name`.

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
| <a name="module_alarms"></a> [alarms](#module\_alarms) | ../../../modules/observability/alarms | n/a |
| <a name="module_alb"></a> [alb](#module\_alb) | ../../../modules/compute/alb-internal | n/a |
| <a name="module_alb_certificate"></a> [alb\_certificate](#module\_alb\_certificate) | ../../../modules/edge/acm-certificate | n/a |
| <a name="module_cluster"></a> [cluster](#module\_cluster) | ../../../modules/compute/ecs-cluster | n/a |
| <a name="module_dashboard"></a> [dashboard](#module\_dashboard) | ../../../modules/observability/dashboard | n/a |
| <a name="module_ecr"></a> [ecr](#module\_ecr) | ../../../modules/compute/ecr-repository | n/a |
| <a name="module_service"></a> [service](#module\_service) | ../../../modules/compute/ecs-service | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ssm_parameter.layer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_vpc_security_group_ingress_rule.db_from_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.endpoints_from_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_ssm_parameters_by_path.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameters_by_path) | data source |
| [aws_ssm_parameters_by_path.network](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameters_by_path) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alb_certificate_arn"></a> [alb\_certificate\_arn](#input\_alb\_certificate\_arn) | Certificado ACM ya emitido en la región de la aplicación para domain\_name. null = el blueprint lo emite en zone\_id. | `string` | `null` | no |
| <a name="input_allow_internet_egress"></a> [allow\_internet\_egress](#input\_allow\_internet\_egress) | Permite a las tareas HTTPS (443) saliente a Internet por la NAT: actívalo si la aplicación llama a APIs externas (pasarela de pagos, correo transaccional...) o descarga imágenes de registros públicos. false (por defecto) = solo endpoints de VPC, S3 y bases de datos. | `bool` | `false` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Dominio público de la tienda: el ALB lleva su certificado regional (CloudFront reenvía el Host, ADR 0007) y solo enruta peticiones con ese Host. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_extra_task_role_policies"></a> [extra\_task\_role\_policies](#input\_extra\_task\_role\_policies) | Políticas JSON adicionales del task role (identidad de la aplicación), por nombre estable, con acciones y recursos explícitos. Las usan los blueprints SaaS que envuelven esta capa. | `map(string)` | `{}` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto (cliente); prefijo de los nombres de recursos y de las rutas SSM. | `string` | n/a | yes |
| <a name="input_service"></a> [service](#input\_service) | Servicio de la aplicación en Fargate: image por digest (en ECR o en un registro alcanzable por la NAT), command (null = el de la imagen), puerto, tamaño, ruta del health check del ALB, variables no secretas y escalado (min\_tasks null = 2 en prod y 1 en el resto). app\_deploys\_outside\_iac = true si el pipeline de la app publica las revisiones (decídelo al adoptar el blueprint: cambiarlo recrea el servicio). volume\_permissions\_image: imagen con chown (p. ej. busybox, por digest en ECR privado) para que el usuario no root de la aplicación pueda escribir en /tmp (Fargate monta los volúmenes como root). | <pre>object({<br/>    image                    = string<br/>    command                  = optional(list(string))<br/>    container_port           = optional(number, 8080)<br/>    cpu                      = optional(number, 512)<br/>    memory                   = optional(number, 1024)<br/>    cpu_architecture         = optional(string, "ARM64")<br/>    health_check_path        = optional(string, "/healthz")<br/>    environment_variables    = optional(map(string), {})<br/>    min_tasks                = optional(number)<br/>    max_tasks                = optional(number, 4)<br/>    app_deploys_outside_iac  = optional(bool, false)<br/>    volume_permissions_image = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales para los recursos (las obligatorias van en default\_tags del provider, en live/). | `map(string)` | `{}` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Zona de Route 53 donde se valida el certificado regional del ALB. null = DNS externo (alb\_certificate\_arn obligatorio). | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ARN del ALB interno (origen del VPC origin de la capa edge). |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | DNS del ALB interno (solo resuelve a IPs privadas). |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Cluster ECS. |
| <a name="output_dashboard_name"></a> [dashboard\_name](#output\_dashboard\_name) | Dashboard de CloudWatch del entorno. |
| <a name="output_ecr_repository_url"></a> [ecr\_repository\_url](#output\_ecr\_repository\_url) | Repositorio ECR de la aplicación (imágenes por digest). |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | Servicio ECS de la aplicación. |
| <a name="output_service_security_group_id"></a> [service\_security\_group\_id](#output\_service\_security\_group\_id) | Security group de las tareas. |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn) | Rol de la aplicación (task role): identidad para permisos adicionales. |
| <a name="output_task_role_name"></a> [task\_role\_name](#output\_task\_role\_name) | Nombre del task role, para adjuntar políticas desde una capa que envuelva esta. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- ALB interno (sin IP pública) con TLS 1.3/1.2, solo enruta el `Host` del dominio público (404 por defecto) y logs de acceso al bucket de logs.
- Tareas sin IP pública, como usuario no root y con el sistema de archivos de solo lectura; su SG solo sale a los endpoints de VPC, S3, PostgreSQL y (opcional) HTTPS por la NAT.
- Task role vacío salvo lo que se inyecte (`extra_task_role_policies`).
- ECS Exec solo fuera de prod.
- Pagos con proveedor PCI DSS nivel 1 (SAQ A).

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
