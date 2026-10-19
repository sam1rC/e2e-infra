# compute/alb-internal

ALB **interno** (nunca público) para servicios en subredes privadas: listener HTTPS 443 con certificado regional, 404 por defecto, reglas por host/path hacia target groups `ip`, security group sin entrada y salida solo a los targets, y logs de acceso a S3.

## Uso

```hcl
module "alb" {
  source = "../../modules/compute/alb-internal"

  project         = "acme"
  environment     = "prod"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.subnet_ids["app"]
  certificate_arn = module.acm_regional.certificate_arn # ACM REGIONAL del dominio público (ADR 0007)

  access_logs_bucket_name = module.alb_logs.bucket_id

  target_groups  = { web = { port = 8080 } }
  listener_rules = { app = { priority = 10, target_group = "web", host_headers = ["app.example.com"] } }
  egress_targets = { web = { security_group_id = module.service.security_group_id, port = 8080 } }
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
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.to_targets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_access_logs_bucket_name"></a> [access\_logs\_bucket\_name](#input\_access\_logs\_bucket\_name) | Bucket S3 de logs de acceso del ALB (cifrado SSE-S3: el ALB no admite SSE-KMS en el bucket de logs). Debe autorizar la entrega del ALB (ver examples/complete). Obligatorio en prod; null = sin logs. | `string` | `null` | no |
| <a name="input_access_logs_prefix"></a> [access\_logs\_prefix](#input\_access\_logs\_prefix) | Prefijo de los logs de acceso dentro del bucket. | `string` | `"alb"` | no |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | Certificado ACM REGIONAL (de la región del ALB, emitido) del dominio público de la aplicación. CloudFront reenvía el Host del visitante y valida este certificado (ADR 0007). | `string` | n/a | yes |
| <a name="input_egress_targets"></a> [egress\_targets](#input\_egress\_targets) | Security groups de destino hacia los que el ALB puede salir, por clave estable (p. ej. el SG del servicio ECS) y el puerto de la app. Es la ÚNICA salida del ALB. Las claves deben ser conocidas al planificar; los IDs pueden depender de otros recursos. | <pre>map(object({<br/>    security_group_id = string<br/>    port              = number<br/>  }))</pre> | `{}` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. En prod el ALB lleva protección contra borrado. | `string` | n/a | yes |
| <a name="input_idle_timeout_seconds"></a> [idle\_timeout\_seconds](#input\_idle\_timeout\_seconds) | Segundos de inactividad antes de cerrar la conexión (1-4000). Debe ser menor que el timeout de lectura del origen en CloudFront. | `number` | `60` | no |
| <a name="input_listener_rules"></a> [listener\_rules](#input\_listener\_rules) | Reglas del listener 443, por clave estable. Cada regla exige al menos un host-header o path y apunta a una clave de target\_groups. Incluye una regla por el dominio público: la acción por defecto es un 404, así el ALB no sirve nada a quien llegue por su DNS interno o con otro Host. | <pre>map(object({<br/>    priority      = number<br/>    target_group  = string<br/>    host_headers  = optional(list(string), [])<br/>    path_patterns = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Nombre del ALB (máx. 32 caracteres). Si es null: <project>-<environment>. Útil cuando un entorno necesita más de un ALB. | `string` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_ssl_policy"></a> [ssl\_policy](#input\_ssl\_policy) | Política TLS del listener HTTPS. Por defecto TLS 1.3 con respaldo a 1.2. | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subredes de la capa app (privadas) del ALB, en al menos 2 AZ (output subnet\_ids["app"] de network/vpc). | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_target_groups"></a> [target\_groups](#input\_target\_groups) | Target groups de tipo ip (Fargate), por clave estable. El nombre real es <project>-<environment>-<clave> (máx. 32 caracteres). El protocolo ALB→tarea es HTTP por defecto: el tráfico no sale de las subredes privadas; usa HTTPS si el contenedor sirve TLS. | <pre>map(object({<br/>    port                 = number<br/>    protocol             = optional(string, "HTTP")<br/>    protocol_version     = optional(string, "HTTP1")<br/>    deregistration_delay = optional(number, 30)<br/>    health_check = optional(object({<br/>      path                = optional(string, "/")<br/>      port                = optional(string, "traffic-port")<br/>      matcher             = optional(string, "200-399")<br/>      interval            = optional(number, 30)<br/>      timeout             = optional(number, 5)<br/>      healthy_threshold   = optional(number, 3)<br/>      unhealthy_threshold = optional(number, 3)<br/>    }), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID de la VPC donde se crea el ALB. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ARN del ALB interno. |
| <a name="output_alb_arn_suffix"></a> [alb\_arn\_suffix](#output\_alb\_arn\_suffix) | Sufijo del ARN del ALB (dimensión LoadBalancer de las métricas de CloudWatch y del ALBRequestCountPerTarget). |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | Nombre DNS del ALB; resuelve solo a IPs privadas. |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | Zona hospedada canónica del ALB. |
| <a name="output_https_listener_arn"></a> [https\_listener\_arn](#output\_https\_listener\_arn) | ARN del listener HTTPS (443). |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group del ALB. El módulo de edge añade la regla de entrada desde CloudFront; los targets la usan como origen permitido. |
| <a name="output_target_group_arn_suffixes"></a> [target\_group\_arn\_suffixes](#output\_target\_group\_arn\_suffixes) | Sufijo del ARN de cada target group, por clave (dimensión TargetGroup de las métricas y de ALBRequestCountPerTarget). |
| <a name="output_target_group_arns"></a> [target\_group\_arns](#output\_target\_group\_arns) | ARN de cada target group, por clave. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Interno y sin entrada propia.** `internal = true` en las subredes `app` (≥ 2 AZ); el DNS del ALB resuelve solo a IPs privadas. El security group nace **sin reglas de entrada**: las añade `edge/cloudfront-vpc-origin` (desde el SG gestionado de los VPC origins) y nada abre `0.0.0.0/0`. Terraform retira la salida abierta que AWS crea por defecto; la **única salida** son las reglas `egress_targets` hacia el SG de los targets en el puerto de la app.
- **Solo HTTPS, TLS ≥ 1.2.** Un único listener 443 con `ssl_policy` limitada a una lista permitida (por defecto `ELBSecurityPolicy-TLS13-1-2-2021-06`) y el certificado **ACM regional** del dominio público: CloudFront reenvía el `Host` del visitante y valida este certificado (ADR 0007). No hay listener 80.
- **404 por defecto.** Sin regla coincidente se devuelve un `fixed-response` 404; solo las reglas de `listener_rules` (con `host_headers`/`path_patterns` obligatorios, validado) llegan a la app. Quien llegue por el DNS interno del ALB o con otro `Host` no alcanza los targets.
- **Endurecimiento del ALB:** `drop_invalid_header_fields`, `desync_mitigation_mode = "strictest"`, protección contra borrado solo en `prod`, `idle_timeout_seconds` configurable (mantenlo por debajo del timeout de lectura del origen en CloudFront).
- **Logs de acceso:** obligatorios en `prod` (`access_logs_bucket_name`). El bucket usa **SSE-S3** porque el ALB no admite SSE-KMS en el bucket de logs, y debe autorizar la entrega del ALB (`examples/complete` muestra la política con `aws_elb_service_account`; las regiones abiertas desde 2022 usan `logdelivery.elasticloadbalancing.amazonaws.com`).
- **Target groups `ip` (Fargate)** con `deregistration_delay = 30`. El tráfico ALB → tarea es HTTP por defecto: no sale de las subredes privadas y el SG de la tarea solo admite el SG del ALB; usa `protocol = "HTTPS"` si el contenedor sirve TLS. Cambiar puerto o protocolo de un target group lo reemplaza.
- **Dependencias circulares evitadas:** la salida del ALB y la entrada del servicio se declaran en recursos separados, así `alb-internal` y `ecs-service` pueden referenciarse entre sí sin ciclo.

### Cómo se verificó

- 17 tests unitarios con `mock_provider` (ALB interno y endurecido, protección según entorno, logs, listener TLS con 404, SG sin entrada y con salida solo a targets, target groups, reglas, y 8 validaciones que deben fallar).
- Plan real offline (provider 6.67.0, sin credenciales) con dos target groups, regla con host y path, logs y salida a un SG: el esquema del provider acepta todos los atributos. Los dos ejemplos validan.
- **Pendiente en sandbox:** `curl` por el DNS interno devuelve 404, el DNS del ALB no resuelve a IP pública y la entrega de logs funciona con la política del ejemplo.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
