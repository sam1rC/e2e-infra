# compute/ecs-service

Servicio **ECS Fargate** endurecido: task definition con contenedor de solo lectura y no root, execution role y task role separados, secretos acotados, logs con KMS, SG sin salida abierta, circuit breaker con rollback, autoscaling y sidecar OpenTelemetry opcional.

## Uso

```hcl
module "service" {
  source = "../../modules/compute/ecs-service"

  project     = "acme"
  environment = "prod"
  name        = "web"
  cluster_arn = module.cluster.cluster_arn
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.subnet_ids["app"]

  image           = "${module.ecr.repository_url}@sha256:..." # siempre por digest
  container_port  = 8080
  log_kms_key_arn = module.kms_logs.key_arn

  alb_security_group_id = module.alb.security_group_id
  target_group_arn      = module.alb.target_group_arns["web"]

  secrets              = { DB_PASSWORD = module.aurora.app_secret_arn }
  secrets_kms_key_arns = [module.kms_data.key_arn]

  egress_rules = {
    vpc_endpoints = { description = "HTTPS a los endpoints de VPC", port = 443, security_group_id = module.vpc_endpoints.security_group_id }
    s3            = { description = "HTTPS al gateway de S3", port = 443, prefix_list_id = module.vpc_endpoints.gateway_endpoint_prefix_list_ids["s3"] }
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
| [aws_appautoscaling_policy.cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.requests](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_service.external](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_service.managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.task_exec_channel](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.task_injected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.task_otel](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.from_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.ecs_tasks_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.exec_channel](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.otel](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alb_arn_suffix"></a> [alb\_arn\_suffix](#input\_alb\_arn\_suffix) | Sufijo del ARN del ALB (output alb\_arn\_suffix de alb-internal); solo para el autoscaling por solicitudes. | `string` | `null` | no |
| <a name="input_alb_enabled"></a> [alb\_enabled](#input\_alb\_enabled) | El servicio recibe tráfico de un ALB (registro en target\_group\_arn y entrada desde alb\_security\_group\_id). Indícalo (true) cuando el ALB se crea en el mismo apply: OpenTofu necesita conocer al planificar si se crea la regla de entrada. null = activado si target\_group\_arn no es null. | `bool` | `null` | no |
| <a name="input_alb_security_group_id"></a> [alb\_security\_group\_id](#input\_alb\_security\_group\_id) | Security group del ALB: único origen permitido de la entrada al puerto del contenedor. null = el servicio no recibe tráfico (workers). | `string` | `null` | no |
| <a name="input_app_deploys_outside_iac"></a> [app\_deploys\_outside\_iac](#input\_app\_deploys\_outside\_iac) | true si el pipeline de la aplicación despliega versiones nuevas (aws ecs update-service): OpenTofu deja de gestionar task\_definition. Cambiar este valor recrea el servicio (la dirección del recurso cambia); decídelo al adoptar el módulo. | `bool` | `false` | no |
| <a name="input_cluster_arn"></a> [cluster\_arn](#input\_cluster\_arn) | ARN del cluster ECS (módulo ecs-cluster). | `string` | n/a | yes |
| <a name="input_command"></a> [command](#input\_command) | Comando del contenedor (sustituye al CMD de la imagen). null = el de la imagen. | `list(string)` | `null` | no |
| <a name="input_container_health_check"></a> [container\_health\_check](#input\_container\_health\_check) | Health check del contenedor (opcional; el del target group ya vigila el servicio). command p. ej. ["CMD-SHELL", "curl -f http://localhost:8080/healthz \|\| exit 1"]. | <pre>object({<br/>    command      = list(string)<br/>    interval     = optional(number, 30)<br/>    timeout      = optional(number, 5)<br/>    retries      = optional(number, 3)<br/>    start_period = optional(number, 0)<br/>  })</pre> | `null` | no |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | Nombre del contenedor de la aplicación. Si es null: el name del servicio. | `string` | `null` | no |
| <a name="input_container_port"></a> [container\_port](#input\_container\_port) | Puerto en el que escucha la aplicación (target group y regla de entrada del SG). | `number` | `8080` | no |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | CPU de la tarea Fargate en unidades (256, 512, 1024, 2048, 4096, 8192 o 16384). | `number` | `512` | no |
| <a name="input_cpu_architecture"></a> [cpu\_architecture](#input\_cpu\_architecture) | Arquitectura de CPU de la tarea: ARM64 (Graviton, por defecto) o X86\_64. La imagen debe construirse para la misma arquitectura. | `string` | `"ARM64"` | no |
| <a name="input_cpu_target_percent"></a> [cpu\_target\_percent](#input\_cpu\_target\_percent) | Objetivo de CPU media (%) del target tracking. | `number` | `60` | no |
| <a name="input_deployment_maximum_percent"></a> [deployment\_maximum\_percent](#input\_deployment\_maximum\_percent) | Porcentaje máximo de tareas durante un despliegue. | `number` | `200` | no |
| <a name="input_deployment_minimum_healthy_percent"></a> [deployment\_minimum\_healthy\_percent](#input\_deployment\_minimum\_healthy\_percent) | Porcentaje mínimo de tareas sanas durante un despliegue. null = 100 en prod y 50 en el resto. En prod no puede ser menor que 100. | `number` | `null` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Número inicial de tareas. null = min\_tasks. Después lo gobierna el autoscaling (el módulo ignora cambios posteriores de desired\_count). | `number` | `null` | no |
| <a name="input_ecr_repository_arns"></a> [ecr\_repository\_arns](#input\_ecr\_repository\_arns) | ARNs de repositorios ECR adicionales desde los que el execution role puede descargar imágenes. Los de image y otel\_image se deducen solos si son de ECR. | `list(string)` | `[]` | no |
| <a name="input_egress_rules"></a> [egress\_rules](#input\_egress\_rules) | Salida del SG de las tareas, por clave estable. Sin reglas, las tareas no salen a ninguna parte: añade los endpoints de VPC (ECR api/dkr, logs, secretsmanager, xray; SG o prefix list del gateway de S3), la base de datos, etc. Cada regla indica exactamente un destino: security\_group\_id, prefix\_list\_id o cidr\_ipv4. | <pre>map(object({<br/>    description       = string<br/>    port              = number<br/>    protocol          = optional(string, "tcp")<br/>    security_group_id = optional(string)<br/>    prefix_list_id    = optional(string)<br/>    cidr_ipv4         = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_enable_exec"></a> [enable\_exec](#input\_enable\_exec) | Activa ECS Exec en el servicio (el cluster debe tener el registro cifrado; ver ecs-cluster). Añade al task role los permisos ssmmessages necesarios. Desaconsejado en prod. | `bool` | `false` | no |
| <a name="input_enable_otel_sidecar"></a> [enable\_otel\_sidecar](#input\_enable\_otel\_sidecar) | Añade el collector AWS Distro for OpenTelemetry (ADOT) como sidecar: trazas OTLP a X-Ray/CloudWatch Application Signals y métricas a CloudWatch. NO uses los SDK ni el daemon de X-Ray (fin de soporte el 25-feb-2027). | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. En prod: mínimo 2 tareas y deployment\_minimum\_healthy\_percent = 100. | `string` | n/a | yes |
| <a name="input_environment_variables"></a> [environment\_variables](#input\_environment\_variables) | Variables de entorno NO secretas del contenedor. Los secretos van en secrets. | `map(string)` | `{}` | no |
| <a name="input_health_check_grace_period_seconds"></a> [health\_check\_grace\_period\_seconds](#input\_health\_check\_grace\_period\_seconds) | Segundos que ECS ignora los health checks del balanceador tras arrancar una tarea. Solo aplica con target\_group\_arn. | `number` | `60` | no |
| <a name="input_image"></a> [image](#input\_image) | Imagen del contenedor referenciada por DIGEST (<repo>@sha256:<64 hex>), nunca por etiqueta mutable. | `string` | n/a | yes |
| <a name="input_log_kms_key_arn"></a> [log\_kms\_key\_arn](#input\_log\_kms\_key\_arn) | CMK que cifra el log group del servicio. Su política debe autorizar a logs.<región>.amazonaws.com. | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retención del log group, en días (valores admitidos por CloudWatch Logs). En prod, al menos 90. | `number` | `90` | no |
| <a name="input_max_tasks"></a> [max\_tasks](#input\_max\_tasks) | Máximo de tareas del autoscaling. | `number` | `4` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | Memoria de la tarea Fargate en MiB (debe ser una combinación válida con cpu). | `number` | `1024` | no |
| <a name="input_min_tasks"></a> [min\_tasks](#input\_min\_tasks) | Mínimo de tareas del autoscaling. null = 2 en prod (una por AZ) y 1 en el resto. | `number` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Nombre del servicio; el servicio, la task definition y los roles se llaman <project>-<environment>-<name>. | `string` | n/a | yes |
| <a name="input_otel_image"></a> [otel\_image](#input\_otel\_image) | Imagen del collector ADOT por DIGEST, copiada a tu ECR privado (public.ecr.aws no es alcanzable sin NAT). Obligatoria con enable\_otel\_sidecar. | `string` | `null` | no |
| <a name="input_permissions_boundary_arn"></a> [permissions\_boundary\_arn](#input\_permissions\_boundary\_arn) | ARN de una permissions boundary para el execution role y el task role. null = ninguna. | `string` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_requests_per_target"></a> [requests\_per\_target](#input\_requests\_per\_target) | Objetivo de ALBRequestCountPerTarget del segundo target tracking. null = solo CPU. Exige alb\_arn\_suffix y target\_group\_arn\_suffix. | `number` | `null` | no |
| <a name="input_scale_in_cooldown_seconds"></a> [scale\_in\_cooldown\_seconds](#input\_scale\_in\_cooldown\_seconds) | Enfriamiento tras reducir tareas. | `number` | `300` | no |
| <a name="input_scale_out_cooldown_seconds"></a> [scale\_out\_cooldown\_seconds](#input\_scale\_out\_cooldown\_seconds) | Enfriamiento tras aumentar tareas. | `number` | `60` | no |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | Secretos inyectados como variables de entorno: nombre → ARN de Secrets Manager (admite sufijo :clave-json::) o de un parámetro SSM. El execution role solo recibe permiso sobre estos ARNs. | `map(string)` | `{}` | no |
| <a name="input_secrets_kms_key_arns"></a> [secrets\_kms\_key\_arns](#input\_secrets\_kms\_key\_arns) | CMKs que cifran los secretos/parámetros de secrets: el execution role recibe kms:Decrypt sobre ellas solo vía Secrets Manager/SSM (kms:ViaService). | `list(string)` | `[]` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subredes de la capa app (privadas) donde corren las tareas, en al menos 2 AZ en prod. Las tareas nunca reciben IP pública. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_target_group_arn"></a> [target\_group\_arn](#input\_target\_group\_arn) | ARN del target group (tipo ip) del ALB al que se registran las tareas. null = sin balanceador. | `string` | `null` | no |
| <a name="input_target_group_arn_suffix"></a> [target\_group\_arn\_suffix](#input\_target\_group\_arn\_suffix) | Sufijo del ARN del target group (output target\_group\_arn\_suffixes de alb-internal); solo para el autoscaling por solicitudes. | `string` | `null` | no |
| <a name="input_task_role_policies"></a> [task\_role\_policies](#input\_task\_role\_policies) | Políticas JSON en línea del task role (el rol de la aplicación), por nombre estable. Vacío por defecto: la aplicación no tiene permisos AWS salvo los que se inyecten aquí (con acciones y recursos explícitos). | `map(string)` | `{}` | no |
| <a name="input_user"></a> [user](#input\_user) | Usuario con el que corre el contenedor (uid[:gid]). No puede ser root. | `string` | `"10001:10001"` | no |
| <a name="input_volume_permissions_image"></a> [volume\_permissions\_image](#input\_volume\_permissions\_image) | Imagen por DIGEST (en tu ECR privado) con el binario chown, p. ej. busybox. Si se indica, un contenedor init no esencial hace chown de writable\_paths al uid:gid de user antes de arrancar la aplicación: Fargate crea esos volúmenes como root 755 y un proceso no root no podría escribir en ellos. Solo conserva la capacidad CHOWN. null = sin contenedor init (la imagen debe declarar las rutas con VOLUME y el propietario correcto, o la aplicación no escribe en disco). | `string` | `null` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID de la VPC del servicio. | `string` | n/a | yes |
| <a name="input_writable_paths"></a> [writable\_paths](#input\_writable\_paths) | Rutas absolutas escribibles (volúmenes efímeros): el sistema de archivos raíz es de solo lectura. Por defecto /tmp. | `list(string)` | <pre>[<br/>  "/tmp"<br/>]</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_autoscaling_resource_id"></a> [autoscaling\_resource\_id](#output\_autoscaling\_resource\_id) | resource\_id del Application Auto Scaling del servicio (para políticas adicionales). |
| <a name="output_execution_role_arn"></a> [execution\_role\_arn](#output\_execution\_role\_arn) | ARN del execution role (descarga de imagen, logs y secretos declarados). |
| <a name="output_log_group_arn"></a> [log\_group\_arn](#output\_log\_group\_arn) | ARN del log group del servicio. |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | Nombre del log group del servicio. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group de las tareas. Añádelo a los orígenes permitidos de los endpoints de VPC y de las bases de datos, y como egress\_targets de alb-internal. |
| <a name="output_service_id"></a> [service\_id](#output\_service\_id) | ARN del servicio ECS. |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | Nombre del servicio ECS. |
| <a name="output_task_definition_arn"></a> [task\_definition\_arn](#output\_task\_definition\_arn) | ARN de la task definition gestionada por OpenTofu (con app\_deploys\_outside\_iac, el pipeline de la aplicación registra revisiones nuevas). |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn) | ARN del task role (identidad de la aplicación; vacío salvo los permisos inyectados). |
| <a name="output_task_role_name"></a> [task\_role\_name](#output\_task\_role\_name) | Nombre del task role, para adjuntar políticas desde fuera del módulo. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Sin IP pública, entrada solo desde el ALB.** Las tareas corren en las subredes `app` (`assign_public_ip = false`). Su security group solo admite el puerto del contenedor **desde el SG del ALB** (sin CIDR). Sin `alb_security_group_id` (workers) no hay entrada alguna.
- **Salida mínima y explícita.** Terraform retira la salida abierta que AWS crea por defecto: las tareas solo salen a lo declarado en `egress_rules` (endpoints de VPC de `ecr.api`, `ecr.dkr`, `logs`, `secretsmanager`, `xray`…, la lista de prefijos del gateway de S3 —`gateway_endpoint_prefix_list_ids` de `vpc-endpoints`—, la base de datos). Cada regla exige exactamente un destino. Sin reglas, las tareas no pueden ni descargar su imagen: es deliberado, el blueprint las declara.
- **Contenedor endurecido:** `readonlyRootFilesystem = true` (las rutas escribibles de `writable_paths`, por defecto `/tmp`, son volúmenes efímeros), usuario **no root** (`user` rechaza uid 0), `privileged = false`, `capabilities.drop = ["ALL"]`, `initProcessEnabled = true`. Si la aplicación necesita escribir en otra ruta, añádela a `writable_paths`.
- **Volúmenes escribibles para un usuario no root:** Fargate crea los volúmenes de `writable_paths` como `root:root 755`, así que un proceso con uid ≠ 0 no puede escribir en ellos (comprobado en la sandbox con nginx-unprivileged). Dos salidas: (a) `volume_permissions_image` (busybox u otra imagen con `chown`, por digest en tu ECR privado) añade un contenedor init no esencial que ejecuta `chown <user> <rutas>` y termina; la aplicación arranca con `dependsOn = SUCCESS`. Es el único contenedor que corre como root: sin puertos, con el root de solo lectura, sin red de entrada y sin capacidades salvo `CHOWN` (Fargate solo permite quitar capacidades, no añadirlas, por eso se enumeran las demás en `drop`). (b) Sin contenedor init: la imagen crea la ruta con el propietario correcto y la declara con `VOLUME`, para que ECS copie su contenido y permisos al volumen (documentado por ECS para Fargate; sin probar en la sandbox). Ninguna de las dos se ha probado aún contra AWS.
- **Imagen por digest.** `image` debe ser `repo@sha256:<64 hex>`: se despliega exactamente lo escaneado. ARM64 (Graviton) por defecto; si la imagen es x86, `cpu_architecture = "X86_64"`.
- **Dos roles, separados.** El **execution role** (lo usa ECS, no la app) tiene una política a medida, sin la política gestionada `AmazonECSTaskExecutionRolePolicy`: `logs:CreateLogStream/PutLogEvents` solo sobre el log group del servicio, `ecr:GetAuthorizationToken` (la única acción con `*`, porque no admite recursos) y el pull solo de los repositorios de la imagen (deducidos de `image`/`otel_image`) más `ecr_repository_arns`. Los secretos son `secrets` (nombre → ARN de Secrets Manager o SSM): el role recibe `secretsmanager:GetSecretValue`/`ssm:GetParameters` **solo sobre esos ARNs** y `kms:Decrypt` solo sobre `secrets_kms_key_arns` con `kms:ViaService`. El **task role** (la identidad de la aplicación) nace **vacío**; los permisos se inyectan con `task_role_policies` (JSON explícito) y ambos roles admiten una permissions boundary. Las dos trust policies exigen `aws:SourceAccount` y `aws:SourceArn` (confused deputy).
- **Logs cifrados:** log group `/ecs/<proyecto>-<entorno>-<nombre>` con CMK y retención (≥ 90 días en prod, validado). La política de la clave debe autorizar a `logs.<región>.amazonaws.com`.
- **Despliegues seguros:** `deployment_circuit_breaker { enable = true, rollback = true }` (una imagen rota revierte sola), `deployment_minimum_healthy_percent = 100` en prod (validado), `propagate_tags = "SERVICE"`, `health_check_grace_period_seconds` configurable. En prod: mínimo 2 tareas (una por AZ) y al menos 2 subredes, ambos validados.
- **Autoscaling:** target tracking por CPU (60 % por defecto) y, opcionalmente, por `ALBRequestCountPerTarget` (`requests_per_target` + los sufijos que da `alb-internal`). El módulo ignora `desired_count` tras la creación porque lo gobierna el autoscaling.
- **Observabilidad con OpenTelemetry (no X-Ray SDK):** `enable_otel_sidecar` añade el collector **ADOT** como sidecar (no esencial, solo lectura, no root) con su configuración de ECS: trazas OTLP a X-Ray y métricas EMF al log group. La imagen (`otel_image`, por digest) debe copiarse a tu ECR privado, porque `public.ecr.aws` no es alcanzable sin NAT. El task role recibe `xray:PutTraceSegments/PutTelemetryRecords` (X-Ray no admite recursos concretos) y `logs:CreateLogStream/PutLogEvents` solo sobre el log group del servicio. No se usan los SDK ni el daemon de X-Ray (fin de soporte el 25-feb-2027).
- **Despliegue desde el pipeline de la aplicación (`app_deploys_outside_iac`).** Con `true`, OpenTofu deja de gestionar `task_definition` (`ignore_changes`) y no desregistra revisiones (`skip_destroy`). `ignore_changes` no admite condiciones, así que el módulo tiene dos recursos de servicio (`managed` y `external`) y **cambiar el valor recrea el servicio**: decídelo al adoptar el módulo. Los dos recursos deben mantenerse con argumentos idénticos.
- **ECS Exec (`enable_exec`)** desactivado por defecto; si se activa, el task role recibe los permisos `ssmmessages` y el cluster debe tener el registro cifrado (`ecs-cluster`).

### Cómo se verificó

- 33 tests unitarios con `mock_provider`: task definition Fargate/awsvpc/ARM64, contenedor endurecido, volúmenes escribibles, logs con KMS, secretos y permisos acotados a sus ARNs, execution role sin comodines salvo `GetAuthorizationToken`, trust policies, task role vacío, políticas inyectadas y boundary, servicio privado con circuit breaker, defaults por entorno, worker sin ALB, SG (solo ALB de entrada, salida declarada), autoscaling por CPU y por solicitudes, despliegue externo, ECS Exec, sidecar OTel y 12 validaciones que deben fallar.
- Los dos ejemplos validan (el completo integra `vpc`, `vpc-endpoints`, `alb-internal`, `ecs-cluster` y KMS) y el grafo de dependencias del ejemplo completo **no tiene ciclos** aunque ALB, servicio y endpoints se referencian entre sí. No se planificó contra AWS real porque el módulo usa data sources de cuenta.
- **Pendiente en sandbox** (criterios de aceptación de la fase): el servicio de ejemplo (`nginx` re-etiquetado en ECR privado) responde 200 a través de CloudFront → ALB interno; una imagen rota provoca rollback automático; las tareas no tienen IP pública; las tareas descargan imagen y secretos solo por los endpoints; el collector ADOT arranca con sistema de archivos de solo lectura y usuario 10001.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
