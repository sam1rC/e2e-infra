# identity/tenant-access-role

**Rol de acceso de un tenant** (patrón *token vending machine*, ABAC con etiquetas de sesión): la aplicación lo asume en cada petición con `sts:AssumeRole` pasando como etiqueta de sesión el tenant que leyó del JWT validado, y todos los permisos del rol se limitan a ese tenant: elementos de DynamoDB cuya clave de partición es el tenant (`dynamodb:LeadingKeys`), objetos de S3 bajo `<prefijo><tenant>/` y uso de KMS con el contexto de cifrado del tenant. Es la capa de aislamiento por IAM de los modelos *pool* (fase 8.2, [ADR 0006](../../../docs/adr/0006-pool-isolation.md)).

## Uso

```hcl
module "tenant_access" {
  source = "../../modules/identity/tenant-access-role"

  project           = "acme"
  environment       = "prod"
  trusted_role_arns = [module.api.role_arn] # rol de ejecución de la Lambda o task role de ECS

  dynamodb_tables = {
    orders = { table_arn = module.orders.table_arn } # tabla con tenant_partition_key = true
  }

  s3_buckets = {
    documents = { bucket_arn = module.documents.bucket_arn, prefix = "tenants/", kms_key_arn = module.kms_data.key_arn }
  }
}
```

El rol de la aplicación necesita además `sts:AssumeRole` y `sts:TagSession` sobre `role_arn` (ver [`examples/complete`](examples/complete)).

### Código de la aplicación (no lo gestiona OpenTofu)

El tenant sale **solo** del JWT ya validado por el autorizador (claim `custom:tenant_id` o el que añada el trigger *pre token generation*), nunca de una cabecera, un parámetro o el cuerpo. Las credenciales se cachean en memoria por tenant para no llamar a STS en cada petición (latencia y cuota de `AssumeRole`):

```python
import time, boto3

_sts = boto3.client("sts")
_cache = {}  # tenant_id -> (credenciales, caducidad)

def tenant_session(tenant_id: str, role_arn: str) -> boto3.Session:
    creds, expires = _cache.get(tenant_id, (None, 0))
    if time.time() > expires - 300:  # renueva 5 min antes de caducar
        resp = _sts.assume_role(
            RoleArn=role_arn,
            RoleSessionName=f"tenant-{tenant_id}"[:64],
            DurationSeconds=3600,
            Tags=[{"Key": "tenant", "Value": tenant_id}],
        )
        creds = resp["Credentials"]
        expires = creds["Expiration"].timestamp()
        _cache[tenant_id] = (creds, expires)
    return boto3.Session(
        aws_access_key_id=creds["AccessKeyId"],
        aws_secret_access_key=creds["SecretAccessKey"],
        aws_session_token=creds["SessionToken"],
    )
```

Con DynamoDB, la clave de partición de cada elemento y de cada consulta debe ser exactamente el `tenant_id`; con KMS en la aplicación, `EncryptionContext={"tenant": tenant_id}` en cifrado y descifrado.

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

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.tenant_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_policy_document.permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_dynamodb_tables"></a> [dynamodb\_tables](#input\_dynamodb\_tables) | Tablas DynamoDB en modo pool, por clave estable. El rol solo accede a los elementos cuya clave de partición sea exactamente el tenant de la sesión (dynamodb:LeadingKeys); la tabla debe crearse con tenant\_partition\_key = true (ADR 0006). include\_indexes da acceso a <tabla>/index/* (todo índice debe tener tenant\_id como clave de partición); read\_only limita a lecturas. | <pre>map(object({<br/>    table_arn       = string<br/>    include_indexes = optional(bool, true)<br/>    read_only       = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_kms_keys"></a> [kms\_keys](#input\_kms\_keys) | CMKs para cifrado en la aplicación (envelope encryption por tenant), por clave estable. El rol solo puede cifrar y descifrar con el contexto de cifrado <tenant\_tag\_key> = <tenant de la sesión>, de modo que un tenant no descifra datos de otro aunque compartan clave. | `map(string)` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Nombre lógico del rol; el nombre real es <project>-<environment>-<name>. | `string` | `"tenant-access"` | no |
| <a name="input_permissions_boundary_arn"></a> [permissions\_boundary\_arn](#input\_permissions\_boundary\_arn) | ARN de una permissions boundary opcional para el rol. | `string` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_s3_buckets"></a> [s3\_buckets](#input\_s3\_buckets) | Buckets S3 con un prefijo por tenant, por clave estable. El rol accede a <bucket>/<prefix><tenant>/* y solo puede listar ese prefijo. kms\_key\_arn (la CMK del bucket, con bucket key activada como en storage/s3-bucket) añade kms:Decrypt/GenerateDataKey limitados a S3 y a ese bucket. read\_only limita a lecturas. | <pre>map(object({<br/>    bucket_arn  = string<br/>    prefix      = optional(string, "")<br/>    kms_key_arn = optional(string)<br/>    read_only   = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_tenant_tag_key"></a> [tenant\_tag\_key](#input\_tenant\_tag\_key) | Clave de la etiqueta de sesión (y del contexto de cifrado KMS) que lleva el identificador del tenant. La aplicación la fija en AssumeRole con el tenant del JWT validado. | `string` | `"tenant"` | no |
| <a name="input_trusted_role_arns"></a> [trusted\_role\_arns](#input\_trusted\_role\_arns) | ARNs de los roles de ejecución de la aplicación (task role de ECS o rol de Lambda) que pueden asumir este rol pasando la etiqueta de sesión del tenant. Solo roles IAM: nunca la raíz de la cuenta, usuarios ni comodines. | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_assume_role_policy_json"></a> [assume\_role\_policy\_json](#output\_assume\_role\_policy\_json) | Trust policy del rol (para revisión y auditoría). |
| <a name="output_permissions_policy_json"></a> [permissions\_policy\_json](#output\_permissions\_policy\_json) | Política de permisos del rol (para revisión y auditoría). |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN del rol de acceso del tenant: la aplicación lo pasa a AssumeRole con Tags=[{Key=<tenant\_tag\_key>, Value=<tenant del JWT>}]. |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Nombre del rol. |
| <a name="output_tenant_tag_key"></a> [tenant\_tag\_key](#output\_tenant\_tag\_key) | Clave de la etiqueta de sesión (y del contexto de cifrado KMS) que debe usar la aplicación. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Trust policy estricta:** solo los roles de `trusted_role_arns` (ARNs de rol validados: nunca `:root`, usuarios ni `*`) pueden hacer `sts:AssumeRole` + `sts:TagSession`, y solo si la petición lleva la etiqueta `<tenant_tag_key>` no vacía (`StringLike "?*"`) y **ninguna otra** (`ForAllValues:StringEquals aws:TagKeys`). Como `ForAllValues` es verdadero cuando la clave no existe, la misma sentencia exige `Null aws:TagKeys = false` (corrección v2.1 del plan).
- **DynamoDB pool:** `ForAllValues:StringEquals dynamodb:LeadingKeys = ${aws:PrincipalTag/<clave>}` **más** `Null dynamodb:LeadingKeys = false` en la misma sentencia: sin el `Null`, cualquier acción permitida que no aporte `LeadingKeys` pasaría la condición. `Scan` y `PartiQL*` se deniegan explícitamente sobre tablas e índices. `LeadingKeys` compara el **valor completo** de la clave de partición: la tabla debe tener `tenant_id` como clave de partición (`tenant_partition_key = true` en `data/dynamodb-table`) y lo mismo cada índice al que se dé acceso (`include_indexes`); ver ADR 0006.
- **S3 por prefijo:** objetos solo bajo `<bucket>/<prefix><tenant>/*` y `ListBucket` solo con `s3:prefix` dentro de ese prefijo (sin `s3:prefix`, listar la raíz queda denegado). La CMK del bucket (`kms_key_arn`) se concede solo `kms:ViaService = s3.<región>` y con `kms:EncryptionContext:aws:s3:arn` = el ARN del bucket, que es el contexto que usa S3 con **bucket key** (activada por `storage/s3-bucket`); sin bucket key el contexto sería el ARN del objeto y la condición no coincidiría.
- **KMS en la aplicación:** `kms_keys` permite cifrar y descifrar solo con `kms:EncryptionContext:<clave> = <tenant de la sesión>`: aunque todos los tenants compartan la clave, uno no puede descifrar datos cifrados con el contexto de otro. Las tablas DynamoDB cifradas con CMK no necesitan permisos KMS en el rol (DynamoDB usa sus propios *grants*).
- **Defensa en profundidad:** `Deny *` si la sesión no lleva la etiqueta del tenant (la trust policy ya lo impide; protege ante un cambio futuro de esa política).
- **Sesiones de 1 hora como máximo** (`max_session_duration = 3600`, fijo): la aplicación asume el rol desde su propio rol, y AWS limita a 1 hora las sesiones de roles encadenados. La caché de credenciales del snippet renueva 5 minutos antes de caducar.
- **Etiqueta `TenantIsolation = session-tag`** en el rol para auditar qué roles aplican este patrón. Las salidas `assume_role_policy_json` y `permissions_policy_json` permiten revisar las políticas en el PR.
- **Fuera de alcance:** el aislamiento en PostgreSQL (RLS o esquema por tenant) va en SQL (`sql/`, fase 8.4) y la validación del JWT, en el autorizador de API Gateway y en la aplicación.

### Cómo se verificó

- 14 tests unitarios con `mock_provider`: trust policy (acciones, principal, etiqueta obligatoria y única, `Null` junto a `ForAllValues`), sesión de 1 hora, `Deny` sin etiqueta, DynamoDB con `LeadingKeys` + `Null` en la misma sentencia y `Scan`/`PartiQL` denegados, tablas de solo lectura sin índices, S3 por prefijo con listado y CMK del bucket acotados, KMS con contexto del tenant y clave de etiqueta personalizada, y 7 validaciones que deben fallar.
- **Plan real offline** contra el provider 6.67.0 (credenciales falsas; el módulo no usa data sources de cuenta): las dos políticas JSON resultantes se revisaron a mano (variables `${aws:PrincipalTag/tenant}` literales para IAM, condiciones en la sentencia correcta).
- **Pendiente en sandbox** (sin coste por hora: IAM, DynamoDB bajo demanda y S3): `tests/integration.tftest.hcl` y la prueba de aislamiento [`tests/integration/tenant-isolation/dynamodb-s3.sh`](../../../tests/integration/tenant-isolation/dynamodb-s3.sh) (pasos 1–3 de la aceptación de la fase 8).

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
