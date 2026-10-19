# saas-t1 / app-app

Capa de aplicación del app plane de SaaS T1: la capa `app` de [`ecommerce-t1`](../../ecommerce-t1/app/README.md) más el aislamiento de tenants (rol ABAC, bucket por prefijo, contexto de cifrado por tenant), la validación de los JWT del control plane y el envío de eventos de uso.

`isolation_model`: `pool` (RLS con `app.current_tenant` por transacción, `sql/pool-rls.sql`), `bridge` (esquema por tenant) o `silo` (cuenta dedicada, `tenant_id` fijo). La aplicación recibe `JWT_ISSUERS`, `TENANT_ID_CLAIM`, `ISOLATION_MODEL`, `TENANT_ROLE_ARN`, `TENANT_TAG_KEY`, `TENANT_BUCKET` y, con metering, `METERING_BUS_ARN`.

## Uso

Composición de referencia (equivale a `live/<env>/app-app` de la fase 10): [`../examples/complete/app-app`](../examples/complete/app-app).

- **Lee de SSM:** `network` y `data` (la capa envuelta) y `network` (CMK de plataforma).
- **Publica en SSM:** lo de `ecommerce-t1/app`.

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
| <a name="module_app"></a> [app](#module\_app) | ../../ecommerce-t1/app | n/a |
| <a name="module_tenant_bucket"></a> [tenant\_bucket](#module\_tenant\_bucket) | ../../../modules/storage/s3-bucket | n/a |
| <a name="module_tenant_role"></a> [tenant\_role](#module\_tenant\_role) | ../../../modules/identity/tenant-access-role | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ssm_parameters_by_path.network](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameters_by_path) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alb_certificate_arn"></a> [alb\_certificate\_arn](#input\_alb\_certificate\_arn) | Certificado ACM ya emitido en la región de la aplicación para domain\_name. null = el blueprint lo emite en zone\_id. | `string` | `null` | no |
| <a name="input_allow_internet_egress"></a> [allow\_internet\_egress](#input\_allow\_internet\_egress) | Permite a las tareas HTTPS (443) saliente a Internet por la NAT: actívalo si la aplicación llama a APIs externas (pasarela de pagos, correo transaccional...) o descarga imágenes de registros públicos. false (por defecto) = solo endpoints de VPC, S3 y bases de datos. | `bool` | `false` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Dominio público de la tienda: el ALB lleva su certificado regional (CloudFront reenvía el Host, ADR 0007) y solo enruta peticiones con ese Host. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_events"></a> [events](#input\_events) | Eventos de dominio: bus de EventBridge con una regla por clave (prefijos de source, p. ej. orders.) hacia Firehose, que los guarda particionados por fecha en el bucket del data lake. | <pre>object({<br/>    archive_retention_days = optional(number)<br/>    source_prefixes        = optional(list(string), ["orders."])<br/>  })</pre> | `{}` | no |
| <a name="input_extra_environment_variables"></a> [extra\_environment\_variables](#input\_extra\_environment\_variables) | Variables de entorno no secretas que añade un blueprint que envuelve esta capa (p. ej. el emisor JWT del control plane en SaaS T1). | `map(string)` | `{}` | no |
| <a name="input_extra_task_role_policies"></a> [extra\_task\_role\_policies](#input\_extra\_task\_role\_policies) | Políticas JSON adicionales del task role (identidad de la aplicación), por nombre estable, con acciones y recursos explícitos. Las usan los blueprints SaaS que envuelven esta capa. | `map(string)` | `{}` | no |
| <a name="input_isolation_model"></a> [isolation\_model](#input\_isolation\_model) | Modelo de aislamiento de los datos relacionales: pool (RLS con app.current\_tenant por transacción), bridge (esquema y rol por tenant) o silo (cuenta dedicada; exige tenant\_id). Lo lee la aplicación; el SQL lo aplica el onboarding (sql/). | `string` | `"pool"` | no |
| <a name="input_jwt_issuers"></a> [jwt\_issuers](#input\_jwt\_issuers) | Emisores de JWT aceptados (salida issuers de la capa control-plane, que vive en otra cuenta): la aplicación valida firma, emisor, audiencia y caducidad y lee el tenant de custom:tenant\_id. | `list(string)` | n/a | yes |
| <a name="input_metering_bus_arn"></a> [metering\_bus\_arn](#input\_metering\_bus\_arn) | Bus de eventos del control plane (salida event\_bus\_arn) donde la aplicación publica los eventos saas.usage. La cuenta de esta capa debe estar en app\_account\_ids del control plane. null = sin metering. | `string` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto (cliente); prefijo de los nombres de recursos y de las rutas SSM. | `string` | n/a | yes |
| <a name="input_service"></a> [service](#input\_service) | Servicio de la aplicación en Fargate: image por digest (en ECR o en un registro alcanzable por la NAT), command (null = el de la imagen), puerto, tamaño, ruta del health check del ALB, variables no secretas y escalado (min\_tasks null = 2 en prod y 1 en el resto) y otel\_image: el collector ADOT por digest (copiado a ECR privado) que alimenta Application Signals; null = sin sidecar (no recomendado en T1). app\_deploys\_outside\_iac = true si el pipeline de la app publica las revisiones (decídelo al adoptar el blueprint: cambiarlo recrea el servicio). volume\_permissions\_image: imagen con chown (p. ej. busybox, por digest en ECR privado) para que el usuario no root de la aplicación pueda escribir en /tmp (Fargate monta los volúmenes como root). | <pre>object({<br/>    image                    = string<br/>    command                  = optional(list(string))<br/>    container_port           = optional(number, 8080)<br/>    cpu                      = optional(number, 512)<br/>    memory                   = optional(number, 1024)<br/>    cpu_architecture         = optional(string, "ARM64")<br/>    health_check_path        = optional(string, "/healthz")<br/>    environment_variables    = optional(map(string), {})<br/>    min_tasks                = optional(number)<br/>    max_tasks                = optional(number, 4)<br/>    app_deploys_outside_iac  = optional(bool, false)<br/>    volume_permissions_image = optional(string)<br/>    otel_image               = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales para los recursos (las obligatorias van en default\_tags del provider, en live/). | `map(string)` | `{}` | no |
| <a name="input_tenant_id"></a> [tenant\_id](#input\_tenant\_id) | Tenant dueño de la cuenta en el modelo silo (la aplicación lo fija y no lo lee del JWT). null en pool y bridge. | `string` | `null` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Zona de Route 53 donde se valida el certificado regional del ALB. null = DNS externo (alb\_certificate\_arn obligatorio). | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ARN del ALB interno (origen del VPC origin de la capa edge). |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | DNS del ALB interno (solo resuelve a IPs privadas). |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Cluster ECS. |
| <a name="output_dashboard_name"></a> [dashboard\_name](#output\_dashboard\_name) | Dashboard de CloudWatch del entorno. |
| <a name="output_data_lake_bucket_id"></a> [data\_lake\_bucket\_id](#output\_data\_lake\_bucket\_id) | Bucket del data lake (eventos particionados por fecha). |
| <a name="output_ecr_repository_url"></a> [ecr\_repository\_url](#output\_ecr\_repository\_url) | Repositorio ECR de la aplicación (imágenes por digest). |
| <a name="output_event_bus_name"></a> [event\_bus\_name](#output\_event\_bus\_name) | Bus de eventos de dominio. |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | Servicio ECS de la aplicación. |
| <a name="output_service_security_group_id"></a> [service\_security\_group\_id](#output\_service\_security\_group\_id) | Security group de las tareas. |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn) | Rol de la aplicación (task role): identidad para permisos adicionales. |
| <a name="output_task_role_name"></a> [task\_role\_name](#output\_task\_role\_name) | Nombre del task role, para adjuntar políticas desde una capa que envuelva esta. |
| <a name="output_tenant_bucket_id"></a> [tenant\_bucket\_id](#output\_tenant\_bucket\_id) | Bucket de datos de tenants (prefijo tenants/<tenant>/). |
| <a name="output_tenant_role_arn"></a> [tenant\_role\_arn](#output\_tenant\_role\_arn) | Rol ABAC que la aplicación asume con la etiqueta de sesión del tenant. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- Las de [`ecommerce-t1/app`](../../ecommerce-t1/app/README.md).
- El task role solo puede asumir el rol de tenant (con `TagSession`) y publicar en el bus del control plane; el rol de tenant solo alcanza `tenants/<tenant>/` y cifra/descifra con el contexto `tenant = <tenant>`.
- Fuga entre tenants por el pool de conexiones: `SET LOCAL`/`set_config(..., true)` por transacción y `RESET ALL` al devolver la conexión (ADR 0009).

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
