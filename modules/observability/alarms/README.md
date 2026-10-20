# observability/alarms

**Topic de SNS cifrado con CMK** y **alarmas de CloudWatch** parametrizadas por tipo de recurso: solo se crean las de los recursos que se declaran. Cubre ALB, ECS, Aurora, RDS, ElastiCache, DynamoDB, Lambda, API Gateway (REST y HTTP), WAF y CloudFront. Todas notifican al topic en el estado de alarma y al recuperarse.

Las alarmas del NAT (`ErrorPortAllocation`) viven en [`network/vpc`](../../network/vpc) y las de backups fallidos en [`resilience/backup-plan`](../../resilience/backup-plan).

## Uso

```hcl
module "alarms" {
  source = "../../modules/observability/alarms"

  project     = "acme"
  environment = "prod"
  kms_key_arn = module.kms_alarms.key_arn # service_principals: cloudwatch.amazonaws.com, sns.amazonaws.com

  email_subscriptions = ["ops@acme.example"]

  alb = {
    web = {
      alb_arn_suffix          = module.alb.alb_arn_suffix
      target_group_arn_suffix = module.alb.target_group_arn_suffixes["web"]
    }
  }

  ecs_services    = { web = { cluster_name = module.cluster.cluster_name, service_name = module.web.service_name, min_running_tasks = 2 } }
  aurora_clusters = { main = { cluster_id = module.aurora.cluster_id, has_replicas = true } }
  dynamodb_tables = { orders = { table_name = module.orders.table_name } }
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
| [aws_cloudwatch_metric_alarm.dynamodb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.simple](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.waf_anomaly](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_sns_topic.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.topic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alb"></a> [alb](#input\_alb) | ALB a vigilar, por clave estable: alb\_arn\_suffix (app/<nombre>/<id>) y target\_group\_arn\_suffix (targetgroup/<nombre>/<id>), salidas de compute/alb-internal. | <pre>map(object({<br/>    alb_arn_suffix          = string<br/>    target_group_arn_suffix = string<br/>  }))</pre> | `{}` | no |
| <a name="input_aurora_clusters"></a> [aurora\_clusters](#input\_aurora\_clusters) | Clusters Aurora, por clave estable: cluster\_id y has\_replicas (activa la alarma de retraso de réplica). | <pre>map(object({<br/>    cluster_id   = string<br/>    has_replicas = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| <a name="input_cloudfront_distributions"></a> [cloudfront\_distributions](#input\_cloudfront\_distributions) | Distribuciones de CloudFront con alarma de 5xxErrorRate, por clave estable: distribution\_id. Sus métricas solo existen en us-east-1: instancia el módulo en esa región (con su propio topic) para ellas. | <pre>map(object({<br/>    distribution_id = string<br/>  }))</pre> | `{}` | no |
| <a name="input_dynamodb_tables"></a> [dynamodb\_tables](#input\_dynamodb\_tables) | Tablas DynamoDB, por clave estable: table\_name y las operaciones sumadas en las alarmas (ThrottledRequests y SystemErrors solo existen por operación). | <pre>map(object({<br/>    table_name = string<br/>    operations = optional(list(string), ["GetItem", "PutItem", "UpdateItem", "DeleteItem", "Query", "Scan", "BatchGetItem", "BatchWriteItem"])<br/>  }))</pre> | `{}` | no |
| <a name="input_ecs_services"></a> [ecs\_services](#input\_ecs\_services) | Servicios ECS, por clave estable: nombre del cluster, del servicio y mínimo de tareas en ejecución (Container Insights debe estar activado en el cluster). | <pre>map(object({<br/>    cluster_name      = string<br/>    service_name      = string<br/>    min_running_tasks = optional(number, 1)<br/>  }))</pre> | `{}` | no |
| <a name="input_elasticache"></a> [elasticache](#input\_elasticache) | Replication groups de ElastiCache, por clave estable: replication\_group\_id y node\_count (num\_cache\_clusters; los nodos se llaman <id>-001, <id>-002...). Se crea una alarma por nodo. | <pre>map(object({<br/>    replication_group_id = string<br/>    node_count           = optional(number, 1)<br/>  }))</pre> | `{}` | no |
| <a name="input_email_subscriptions"></a> [email\_subscriptions](#input\_email\_subscriptions) | Correos suscritos al topic. Cada destinatario debe confirmar la suscripción desde el mensaje que recibe de AWS; hasta entonces no recibe alarmas. | `list(string)` | `[]` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_existing_topic_arn"></a> [existing\_topic\_arn](#input\_existing\_topic\_arn) | Topic SNS ya existente (cifrado) al que envían las alarmas, p. ej. el que crea la capa network de un blueprint para todo el entorno. null = el módulo crea su propio topic con kms\_key\_arn y las suscripciones. | `string` | `null` | no |
| <a name="input_http_apis"></a> [http\_apis](#input\_http\_apis) | APIs HTTP de API Gateway, por clave estable: api\_id y stage ($default si no se nombra). | <pre>map(object({<br/>    api_id = string<br/>    stage  = optional(string, "$default")<br/>  }))</pre> | `{}` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN de la CMK que cifra el topic de SNS. Su política debe autorizar a los servicios que publican (cloudwatch.amazonaws.com y los de publisher\_service\_principals) con kms:GenerateDataKey* y kms:Decrypt: usa service\_principals en foundation/kms-key. Con una clave sin ese permiso las alarmas no pueden notificar. | `string` | n/a | yes |
| <a name="input_lambda_functions"></a> [lambda\_functions](#input\_lambda\_functions) | Funciones Lambda, por clave estable: function\_name y timeout\_seconds (la alarma de duración p95 salta al superar el porcentaje thresholds.lambda\_duration\_p95\_ratio del timeout). | <pre>map(object({<br/>    function_name   = string<br/>    timeout_seconds = optional(number, 30)<br/>  }))</pre> | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Prefijo de las alarmas y nombre del topic. Si es null: <project>-<environment>. | `string` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_publisher_service_principals"></a> [publisher\_service\_principals](#input\_publisher\_service\_principals) | Servicios autorizados a publicar en el topic (con aws:SourceAccount). CloudWatch siempre; añade events.amazonaws.com o backup.amazonaws.com si otras reglas del entorno usan este topic. | `list(string)` | <pre>[<br/>  "cloudwatch.amazonaws.com"<br/>]</pre> | no |
| <a name="input_rds_instances"></a> [rds\_instances](#input\_rds\_instances) | Instancias RDS, por clave estable: instance\_id. | <pre>map(object({<br/>    instance_id = string<br/>  }))</pre> | `{}` | no |
| <a name="input_rest_apis"></a> [rest\_apis](#input\_rest\_apis) | APIs REST de API Gateway, por clave estable: api\_name y stage. | <pre>map(object({<br/>    api_name = string<br/>    stage    = string<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_thresholds"></a> [thresholds](#input\_thresholds) | Umbrales y ventanas de evaluación. Los valores por defecto son un punto de partida: ajústalos al tamaño real de cada servicio (p. ej. db\_connections según la clase de instancia). | <pre>object({<br/>    period_seconds                  = optional(number, 300)<br/>    evaluation_periods              = optional(number, 3)<br/>    datapoints_to_alarm             = optional(number, 2)<br/>    alb_target_5xx_count            = optional(number, 10)<br/>    alb_response_time_p99_seconds   = optional(number, 2)<br/>    alb_unhealthy_hosts             = optional(number, 1)<br/>    ecs_cpu_percent                 = optional(number, 85)<br/>    ecs_memory_percent              = optional(number, 85)<br/>    db_cpu_percent                  = optional(number, 80)<br/>    db_freeable_memory_bytes        = optional(number, 268435456)<br/>    db_connections                  = optional(number, 400)<br/>    aurora_replica_lag_milliseconds = optional(number, 1000)<br/>    rds_free_storage_bytes          = optional(number, 10737418240)<br/>    cache_engine_cpu_percent        = optional(number, 80)<br/>    cache_memory_percent            = optional(number, 80)<br/>    cache_evictions                 = optional(number, 100)<br/>    dynamodb_throttled_requests     = optional(number, 5)<br/>    dynamodb_system_errors          = optional(number, 1)<br/>    lambda_errors                   = optional(number, 1)<br/>    lambda_throttles                = optional(number, 1)<br/>    lambda_duration_p95_ratio       = optional(number, 0.8)<br/>    api_5xx_count                   = optional(number, 5)<br/>    api_latency_p95_milliseconds    = optional(number, 1500)<br/>    waf_anomaly_band_width          = optional(number, 4)<br/>    cloudfront_5xx_percent          = optional(number, 5)<br/>  })</pre> | `{}` | no |
| <a name="input_waf_web_acls"></a> [waf\_web\_acls](#input\_waf\_web\_acls) | Web ACL de WAF con alarma de BlockedRequests anómalo (banda de detección de anomalías), por clave estable: web\_acl\_name y region\_dimension (la región del ACL regional, o Global para scope CLOUDFRONT; las métricas de CloudFront/WAF global solo existen en us-east-1, así que instancia el módulo en esa región para ellos). | <pre>map(object({<br/>    web_acl_name     = string<br/>    region_dimension = optional(string, "Global")<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alarm_arns"></a> [alarm\_arns](#output\_alarm\_arns) | ARN de todas las alarmas creadas, por nombre lógico (para el widget de estado del dashboard). |
| <a name="output_alarm_count"></a> [alarm\_count](#output\_alarm\_count) | Número de alarmas creadas. |
| <a name="output_topic_arn"></a> [topic\_arn](#output\_topic\_arn) | ARN del topic de alarmas (el creado, cifrado con la CMK, o existing\_topic\_arn). Úsalo como destino de otras alarmas o reglas de este entorno (alarm\_actions). |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Topic cifrado y acotado:** `kms_master_key_id` con la CMK del entorno (su política debe autorizar a `cloudwatch.amazonaws.com` y a los demás publicadores con `kms:GenerateDataKey*`/`kms:Decrypt`: usa `service_principals` de `foundation/kms-key`; sin ello las alarmas no pueden notificar). La política del topic solo admite `sns:Publish` de los servicios de `publisher_service_principals` con `aws:SourceAccount`, deja la gestión a la propia cuenta y deniega el transporte sin TLS enumerando las acciones de nivel de tema (SNS rechaza `sns:*` en las políticas de tema: comprobado contra AWS el 2026-10-06).
- **Suscripciones por correo** (`email_subscriptions`; obligatorias en prod): cada destinatario debe confirmar la suscripción desde el mensaje de AWS. Hasta entonces no recibe nada; comprueba la confirmación tras el primer despliegue.
- **`treat_missing_data` por métrica:** las de recuento (5XX, errores, limitaciones, expulsiones) usan `notBreaching` (sin tráfico no hay error) y las de utilización también; `RunningTaskCount` de ECS usa `breaching` (sin datos es que no hay tareas informando) y la alarma salta con menos tareas que `min_running_tasks`.
- **Una alarma por nodo en ElastiCache** (las métricas se publican por `CacheClusterId`, `<grupo>-001`…): se construyen a partir de `node_count`, que debe coincidir con `num_cache_clusters`.
- **DynamoDB:** `ThrottledRequests` y `SystemErrors` solo existen por operación, así que cada alarma suma con metric math (`SUM(METRICS())`) las operaciones de `operations`; añade las que use tu aplicación (p. ej. `TransactWriteItems`).
- **WAF:** `BlockedRequests` se vigila con detección de anomalías (`ANOMALY_DETECTION_BAND`), no con un umbral fijo. Los scopes `CLOUDFRONT` y las métricas de **CloudFront** solo existen en **us-east-1**: instancia el módulo una segunda vez en esa región (`providers = { aws = aws.us_east_1 }`, con su propio topic y su CMK) solo con `waf_web_acls` y `cloudfront_distributions`.
- **Umbrales por defecto = punto de partida:** `thresholds` agrupa todos (ventana de 5 min, 2 de 3 puntos). Ajusta sobre todo `db_connections` (según la clase de instancia), `alb_response_time_p99_seconds` y `cloudfront_5xx_percent` al SLO real de cada servicio. El umbral de duración de Lambda es el 80 % del `timeout_seconds` indicado.
- **Nombres:** `<project>-<env>-<tipo>-<clave>-<métrica>`, con claves estables derivadas de las claves de los mapas de entrada.

### Cómo se verificó

- 23 tests unitarios con `mock_provider` (topic cifrado y política, una alarma por tipo y recurso con sus dimensiones y estadísticos, retraso de réplica solo con réplicas, alarmas por nodo, suma por operación en DynamoDB, banda de anomalías en WAF, `treat_missing_data` de ECS, notificación de todas las alarmas al topic, umbrales ajustables y 8 validaciones que deben fallar). Los dos ejemplos validan.
- **Plan real offline** contra el provider 6.67.0 (credenciales falsas; cuenta sustituida por una constante): 30 alarmas + topic, política y suscripción; esquema de `metric_query` y de `ANOMALY_DETECTION_BAND` aceptado.
- **Pendiente en sandbox** (aceptación de la fase 7): las alarmas existen y apuntan al topic cifrado; forzar una alarma (`aws cloudwatch set-alarm-state`) entrega el correo; la dimensión `Region = Global` de CloudFront/WAF global y los nombres de dimensión de cada métrica se han tomado de la documentación de AWS, sin comprobar contra recursos reales.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
