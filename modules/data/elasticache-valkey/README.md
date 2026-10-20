# data/elasticache-valkey

**Replication group de ElastiCache for Valkey** cifrado en tránsito y en reposo, con **autenticación IAM** (sin contraseñas ni AUTH token), sin usuario `default` (ninguna conexión sin autenticar), failover automático y Multi-AZ con 2 o más nodos, copias diarias y slow-log/engine-log cifrados en CloudWatch Logs.

## Uso

```hcl
module "valkey" {
  source = "../../modules/data/elasticache-valkey"

  project     = "acme"
  environment = "prod"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.subnet_ids["data"]
  kms_key_arn = module.kms_data.key_arn # service_principals: logs.<región>.amazonaws.com; via_services: elasticache.<región>.amazonaws.com

  node_type = "cache.m7g.large"

  allowed_security_group_ids = {
    app = module.ecs_service.security_group_id
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
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_elasticache_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_parameter_group) | resource |
| [aws_elasticache_replication_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group) | resource |
| [aws_elasticache_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_subnet_group) | resource |
| [aws_elasticache_user.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_user) | resource |
| [aws_elasticache_user_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_user_group) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_parameter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_vpc_security_group_ingress_rule.from_allowed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allowed_security_group_ids"></a> [allowed\_security\_group\_ids](#input\_allowed\_security\_group\_ids) | Security groups autorizados a conectar al puerto de Valkey, como mapa nombre estable => ID. Un mapa (y no una lista) permite pasar IDs que aún no existen: las claves son conocidas al planificar. El SG no tiene reglas de salida. | `map(string)` | `{}` | no |
| <a name="input_apply_immediately"></a> [apply\_immediately](#input\_apply\_immediately) | Aplica los cambios sin esperar a la ventana de mantenimiento (útil en dev; en prod mejor false). | `bool` | `false` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | Versión de Valkey (7.2 o superior; la autenticación IAM exige >= 7.2 con TLS). Verifica las disponibles con `aws elasticache describe-cache-engine-versions --engine valkey`. La familia del parameter group (valkey7, valkey8...) se deduce de la versión mayor. | `string` | `"8.2"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_final_snapshot_enabled"></a> [final\_snapshot\_enabled](#input\_final\_snapshot\_enabled) | Crea una copia final (<name>-final) al destruir el replication group. Si ya existe una con ese nombre, la destrucción falla: bórrala antes. Obligatoria en prod. | `bool` | `true` | no |
| <a name="input_iam_users"></a> [iam\_users](#input\_iam\_users) | Usuarios de aplicación con autenticación IAM, por clave estable (el user\_id es <name>-<clave>). access\_string es el ACL de Valkey: por defecto todo salvo los comandos peligrosos (FLUSHALL, KEYS, CONFIG...). No hay usuario default: sin un usuario IAM nadie conecta. No hay contraseñas ni AUTH token. | <pre>map(object({<br/>    access_string = optional(string, "on ~* +@all -@dangerous")<br/>  }))</pre> | <pre>{<br/>  "app": {}<br/>}</pre> | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN de la CMK del entorno: cifra los datos en reposo, las copias y los log groups. Su política debe autorizar a logs.<región>.amazonaws.com (service\_principals de foundation/kms-key) y a ElastiCache vía kms:ViaService. | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retención de los log groups de slow-log y engine-log, en días (valores admitidos por CloudWatch Logs). En prod, al menos 90. | `number` | `90` | no |
| <a name="input_maxmemory_policy"></a> [maxmemory\_policy](#input\_maxmemory\_policy) | Política de expulsión cuando se llena la memoria: volatile-lru (caché con TTL), allkeys-lru, allkeys-lfu, volatile-lfu, volatile-random, allkeys-random, volatile-ttl o noeviction (sesiones o colas: devuelve error en vez de expulsar). | `string` | `"volatile-lru"` | no |
| <a name="input_name"></a> [name](#input\_name) | Identificador del replication group (también prefijo de usuarios, grupo y parameter group). Si es null: <project>-<environment>-valkey. Máximo 23 caracteres: los IDs de usuario de ElastiCache admiten 40 y llevan el sufijo -<clave> (hasta 16). | `string` | `null` | no |
| <a name="input_node_type"></a> [node\_type](#input\_node\_type) | Tipo de nodo (Graviton: cache.t4g.small en dev, cache.m7g.large o mayor en prod). | `string` | `"cache.t4g.small"` | no |
| <a name="input_num_cache_clusters"></a> [num\_cache\_clusters](#input\_num\_cache\_clusters) | Número de nodos (1 primario + réplicas). Con 2 o más se activan failover automático y Multi-AZ. null = 2 en prod y 1 en el resto; en prod, mínimo 2. | `number` | `null` | no |
| <a name="input_port"></a> [port](#input\_port) | Puerto de Valkey. | `number` | `6379` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_publish_ssm_parameters"></a> [publish\_ssm\_parameters](#input\_publish\_ssm\_parameters) | Publica endpoints y ARNs en SSM Parameter Store bajo /<project>/<env>/data/<ssm\_namespace>/ para las capas consumidoras. | `bool` | `true` | no |
| <a name="input_snapshots"></a> [snapshots](#input\_snapshots) | Copias de seguridad diarias: retention\_days (0 las desactiva; en prod, al menos 7) y window (hh:mm-hh:mm UTC, sin solaparse con maintenance\_window). | <pre>object({<br/>    retention_days     = optional(number, 7)<br/>    window             = optional(string, "03:00-04:00")<br/>    maintenance_window = optional(string, "sun:05:00-sun:06:00")<br/>  })</pre> | `{}` | no |
| <a name="input_ssm_namespace"></a> [ssm\_namespace](#input\_ssm\_namespace) | Segmento de la ruta SSM (evita colisiones si hay más de un Valkey en el entorno). | `string` | `"valkey"` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subredes de la capa data (al menos 2, en AZ distintas) para el subnet group. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC donde se crea el security group. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_iam_connect_resource_arns"></a> [iam\_connect\_resource\_arns](#output\_iam\_connect\_resource\_arns) | ARNs para elasticache:Connect, por clave de iam\_users: [replication group, usuario]. Úsalos en el task role de la aplicación (ambos ARN son necesarios). |
| <a name="output_iam_user_names"></a> [iam\_user\_names](#output\_iam\_user\_names) | Nombre del usuario de ElastiCache por clave de iam\_users: es el valor de `User` al firmar el token IAM. |
| <a name="output_log_group_names"></a> [log\_group\_names](#output\_log\_group\_names) | Log groups de slow-log y engine-log. |
| <a name="output_port"></a> [port](#output\_port) | Puerto de Valkey. |
| <a name="output_primary_endpoint"></a> [primary\_endpoint](#output\_primary\_endpoint) | Endpoint del nodo primario (lecturas y escrituras). |
| <a name="output_reader_endpoint"></a> [reader\_endpoint](#output\_reader\_endpoint) | Endpoint de lectura (reparte entre las réplicas). |
| <a name="output_replication_group_arn"></a> [replication\_group\_arn](#output\_replication\_group\_arn) | ARN del replication group. |
| <a name="output_replication_group_id"></a> [replication\_group\_id](#output\_replication\_group\_id) | ID del replication group: es el "nombre de host" que firma el token IAM (no el endpoint). |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group del cache (sin reglas de salida). |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Cifrado:** `transit_encryption_enabled = true` con `transit_encryption_mode = "required"` (sin conexiones en claro) y `at_rest_encryption_enabled` con la CMK del entorno. Los dos log groups (`/aws/elasticache/<name>/slow-log` y `engine-log`, en JSON) se crean antes con la CMK y retención (90 días mínimo en prod).
- **Sin contraseñas ni AUTH token en ninguna parte:** cada entrada de `iam_users` crea un `aws_elasticache_user` con `authentication_mode { type = "iam" }` (`user_id` = `user_name` = `<name>-<clave>`). El grupo de usuarios no incluye el usuario `default` (que aceptaría clientes sin credenciales): con el motor Valkey no es obligatorio y ElastiCache rechaza crearlo sin contraseña (comprobado en la sandbox el 2026-10-14).
- **ACL por usuario:** por defecto `on ~* +@all -@dangerous` (todo salvo FLUSHALL, KEYS, CONFIG…); la validación exige que empiece por `on `, porque un usuario desactivado no podría conectar. Define usuarios de solo lectura con `on ~* +@read -@dangerous`.
- **Red cerrada:** subnet group de la capa `data` y un SG **sin reglas de salida** cuya entrada es TCP al puerto de Valkey solo desde los SG de `allowed_security_group_ids` (mapa nombre → ID; nunca CIDR).
- **Alta disponibilidad:** `num_cache_clusters >= 2` activa `automatic_failover_enabled` y `multi_az_enabled`; en prod el mínimo es 2 (validado). En dev, 1 nodo.
- **Copias:** `snapshots.retention_days` (7 por defecto, mínimo 7 en prod; 0 las desactiva) y copia final `<name>-final` al destruir (obligatoria en prod). Si ya existe una copia con ese nombre, la destrucción falla: bórrala antes.
- **`maxmemory-policy`** configurable (`volatile-lru` por defecto, adecuado para caché con TTL; usa `noeviction` para sesiones o colas, que prefieren un error a perder claves). La familia del parameter group (`valkey7`, `valkey8`, `valkey9`) se deduce de `engine_version`, que debe ser 7.2 o superior. Por defecto `8.2` (versiones disponibles en us-east-1 el 2026-10-05: 7.2, 8.0–8.2 y 9.0–9.1).
- **Longitud del nombre:** `name` admite 23 caracteres como máximo, porque los IDs de usuario de ElastiCache (40 como máximo) llevan el sufijo `-<clave de hasta 16>`; el nombre por defecto `<project>-<env>-valkey` se valida igual.
- **SSM** (`/<project>/<env>/data/valkey/…`): `primary_endpoint`, `reader_endpoint`, `port`, `replication_group_id` y `replication_group_arn`. Solo endpoints e identificadores (ADR 0004).

### Conexión con IAM desde la aplicación

1. **Permisos del task role** (acciones y recursos explícitos): `elasticache:Connect` sobre **los dos ARN** de la salida `iam_connect_resource_arns["app"]` (el replication group y el usuario).
2. **Token:** se genera firmando con SigV4 una petición `connect` y es válido **15 minutos**. El nombre de host que se firma es el `replication_group_id` (salida del módulo), no el endpoint. Una conexión autenticada vive como máximo **12 horas**: la aplicación debe volver a autenticarse (`AUTH <usuario> <token nuevo>`) antes de ese límite y reconectar si falla. Valkey 7.2 o superior y TLS son obligatorios.
3. **Cliente:** conecta por TLS (`rediss://`) al `primary_endpoint` (escrituras) o al `reader_endpoint` (lecturas), con el usuario de `iam_user_names["app"]` y el token como contraseña.

```python
import botocore.session
from botocore.model import ServiceId
from botocore.signers import RequestSigner
from urllib.parse import urlencode, urlunparse


class ElastiCacheIamToken:
    def __init__(self, user: str, replication_group_id: str, region: str):
        self.user, self.group, self.region = user, replication_group_id, region
        session = botocore.session.get_session()
        self.signer = RequestSigner(
            ServiceId("elasticache"), region, "elasticache", "v4",
            session.get_credentials(), session.get_component("event_emitter"),
        )

    def get(self) -> str:
        url = urlunparse(("https", self.group, "/", "", urlencode({"Action": "connect", "User": self.user}), ""))
        signed = self.signer.generate_presigned_url(
            {"method": "GET", "url": url, "body": {}, "headers": {}, "context": {}},
            operation_name="connect", expires_in=900, region_name=self.region,
        )
        return signed.removeprefix("https://")  # úsalo como contraseña; renuévalo cada < 15 min
```

### Cómo se verificó

- 28 tests unitarios con `mock_provider` (cifrado en tránsito/reposo y ausencia de AUTH token, usuario `default` deshabilitado, usuarios IAM sin contraseña, varios usuarios con su ACL, failover y Multi-AZ según nodos, valores por defecto de prod, familia del parameter group, copias, log groups cifrados, SG por referencia, ARN de `elasticache:Connect`, SSM y 12 validaciones que deben fallar). Los dos ejemplos validan y su grafo es acíclico.
- **Plan real offline** contra el provider 6.67.0 (credenciales falsas; el módulo no tiene data sources): 16 recursos, esquema aceptado (usuarios IAM, usuario `default` con `no-password-required`, grupo de usuarios con el `engine = "valkey"`, `log_delivery_configuration` de dos destinos).
- **Pendiente en sandbox:** crear el grupo con la clave del ejemplo (los log groups exigen la política de CloudWatch Logs), conectar con un token IAM y comprobar que sin TLS o sin credenciales se rechaza; verificar `engine_version` (`8.0` no se ha comprobado contra la API) y que ElastiCache acepta el `access_string` por defecto.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
