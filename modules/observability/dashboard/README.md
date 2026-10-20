# observability/dashboard

**Dashboard de CloudWatch** de un blueprint, generado con `jsonencode` a partir de los recursos que se declaran: un panel de estado de alarmas y, por cada tipo de recurso presente (ALB, ECS, Aurora, RDS, ElastiCache, DynamoDB, Lambda, API Gateway, CloudFront, WAF), sus widgets de métricas en una cuadrícula de dos columnas. Con `application_signals` añade los widgets de **CloudWatch Application Signals** (latencia, fallos/errores y disponibilidad) alimentados por el sidecar ADOT de `ecs-service`.

## Uso

```hcl
module "dashboard" {
  source = "../../modules/observability/dashboard"

  project     = "acme"
  environment = "prod"
  name        = "acme-prod-ecommerce-t1"

  alarm_arns          = module.alarms.alarm_arns
  application_signals = { service_name = "acme-prod-web", environment_name = "ecs:acme-prod" }

  alb          = { web = { alb_arn_suffix = module.alb.alb_arn_suffix, target_group_arn_suffix = module.alb.target_group_arn_suffixes["web"] } }
  ecs_services = { web = { cluster_name = module.cluster.cluster_name, service_name = module.web.service_name } }
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
| [aws_cloudwatch_dashboard.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alarm_arns"></a> [alarm\_arns](#input\_alarm\_arns) | ARN de las alarmas que muestra el widget de estado (salida alarm\_arns de observability/alarms). | `map(string)` | `{}` | no |
| <a name="input_alb"></a> [alb](#input\_alb) | ALB, por clave estable: alb\_arn\_suffix y target\_group\_arn\_suffix. | <pre>map(object({<br/>    alb_arn_suffix          = string<br/>    target_group_arn_suffix = string<br/>  }))</pre> | `{}` | no |
| <a name="input_application_signals"></a> [application\_signals](#input\_application\_signals) | Servicio con CloudWatch Application Signals (alimentado por el sidecar ADOT de ecs-service): service\_name y environment\_name tal como aparecen en Application Signals. Añade widgets de latencia, fallos, errores y disponibilidad. null = sin ellos. Los SLO no los crea este módulo (el provider no tiene recurso): ver el README. | <pre>object({<br/>    service_name     = string<br/>    environment_name = string<br/>  })</pre> | `null` | no |
| <a name="input_aurora_clusters"></a> [aurora\_clusters](#input\_aurora\_clusters) | Clusters Aurora, por clave estable: cluster\_id. | <pre>map(object({<br/>    cluster_id = string<br/>  }))</pre> | `{}` | no |
| <a name="input_cloudfront_distributions"></a> [cloudfront\_distributions](#input\_cloudfront\_distributions) | Distribuciones de CloudFront, por clave estable: distribution\_id (sus métricas están en us-east-1; el widget lo indica y el dashboard puede estar en cualquier región). | <pre>map(object({<br/>    distribution_id = string<br/>  }))</pre> | `{}` | no |
| <a name="input_dynamodb_tables"></a> [dynamodb\_tables](#input\_dynamodb\_tables) | Tablas DynamoDB, por clave estable: table\_name. | <pre>map(object({<br/>    table_name = string<br/>  }))</pre> | `{}` | no |
| <a name="input_ecs_services"></a> [ecs\_services](#input\_ecs\_services) | Servicios ECS, por clave estable: cluster\_name y service\_name. | <pre>map(object({<br/>    cluster_name = string<br/>    service_name = string<br/>  }))</pre> | `{}` | no |
| <a name="input_elasticache"></a> [elasticache](#input\_elasticache) | Replication groups de ElastiCache, por clave estable: replication\_group\_id y node\_count (los nodos se llaman <id>-001, <id>-002...). | <pre>map(object({<br/>    replication_group_id = string<br/>    node_count           = optional(number, 1)<br/>  }))</pre> | `{}` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_http_apis"></a> [http\_apis](#input\_http\_apis) | APIs HTTP de API Gateway, por clave estable: api\_id y stage ($default si no se nombra). | <pre>map(object({<br/>    api_id = string<br/>    stage  = optional(string, "$default")<br/>  }))</pre> | `{}` | no |
| <a name="input_lambda_functions"></a> [lambda\_functions](#input\_lambda\_functions) | Funciones Lambda, por clave estable: function\_name. | <pre>map(object({<br/>    function_name = string<br/>  }))</pre> | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Nombre del dashboard (uno por blueprint, p. ej. acme-prod-ecommerce-t1). Si es null: <project>-<environment>. | `string` | `null` | no |
| <a name="input_period_seconds"></a> [period\_seconds](#input\_period\_seconds) | Resolución de las series, en segundos (múltiplo de 60). | `number` | `300` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_rds_instances"></a> [rds\_instances](#input\_rds\_instances) | Instancias RDS, por clave estable: instance\_id. | <pre>map(object({<br/>    instance_id = string<br/>  }))</pre> | `{}` | no |
| <a name="input_rest_apis"></a> [rest\_apis](#input\_rest\_apis) | APIs REST de API Gateway, por clave estable: api\_name y stage. | <pre>map(object({<br/>    api_name = string<br/>    stage    = string<br/>  }))</pre> | `{}` | no |
| <a name="input_waf_web_acls"></a> [waf\_web\_acls](#input\_waf\_web\_acls) | Web ACL de WAF, por clave estable: web\_acl\_name y region\_dimension (Global para scope CLOUDFRONT, que vive en us-east-1; la región del ACL si es regional). | <pre>map(object({<br/>    web_acl_name     = string<br/>    region_dimension = optional(string, "Global")<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_dashboard_arn"></a> [dashboard\_arn](#output\_dashboard\_arn) | ARN del dashboard. |
| <a name="output_dashboard_name"></a> [dashboard\_name](#output\_dashboard\_name) | Nombre del dashboard. |
| <a name="output_widget_count"></a> [widget\_count](#output\_widget\_count) | Número de widgets del dashboard (el límite de CloudWatch es 500). |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Sin datos sensibles:** solo contiene nombres y ARN de recursos y métricas; no hay secretos ni valores de negocio.
- **Misma identidad que las alarmas:** los mapas de entrada tienen las mismas claves y atributos que los de `observability/alarms`, de modo que el blueprint los declara una vez y los pasa a ambos módulos (ver `examples/complete`).
- **CloudFront y WAF global** consultan us-east-1 en el propio widget (`region`), así que el dashboard puede crearse en cualquier región; las dimensiones `Region = Global` se han tomado de la documentación de AWS.
- **Límites:** CloudWatch admite hasta 500 widgets y 1 MB por dashboard; la salida `widget_count` permite vigilar el primero.
- **`application_signals` y SLO:** `service_name` y `environment_name` deben coincidir con lo que muestra Application Signals (para ECS, normalmente `ecs:<cluster>`). **Este módulo no crea los SLO ni activa Application Signals**: el provider `hashicorp/aws` 6.67 no tiene recursos para ello. Hay que habilitar el descubrimiento (`aws application-signals start-discovery`) y crear los SLO de latencia y disponibilidad del servicio con `aws application-signals create-service-level-objective` o desde la consola, y registrarlo en el runbook del blueprint (desviación del plan, ADR 0014). La disponibilidad del dashboard se calcula como `100 * (1 - Fault / peticiones)` con las peticiones como nº de muestras de `Latency`.

### Cómo se verificó

- 14 tests unitarios con `mock_provider` (dashboard vacío, nombre por blueprint, 19 widgets para los 9 tipos de recurso declarados, cuadrícula de dos columnas, widget de alarmas arriba, región/resolución/título de cada widget, formato de las filas de métricas, una fila por nodo en ElastiCache, regiones de CloudFront/WAF, widgets de Application Signals y 3 validaciones que deben fallar). Un test detectó que `flatten` aplanaba también las filas de métricas de ElastiCache (JSON inválido) y se corrigió con `concat`. Los dos ejemplos validan y su grafo es acíclico.
- **Pendiente en sandbox:** crear el dashboard del ejemplo (CloudWatch rechaza los cuerpos mal formados solo al aplicarlos) y comprobar visualmente los widgets, sobre todo los de Application Signals con un servicio real.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
