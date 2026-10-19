# Blueprint E-commerce T1 (Enterprise)

Tienda con frontend y API en contenedores (ECS Fargate detrás de un ALB interno), Aurora PostgreSQL y caché Valkey, servida solo a través de CloudFront + WAF. Máxima disponibilidad en la región y copia de backups a una región de DR.

Diagrama (v2): https://lucid.app/lucidchart/fefe40ec-ddca-483a-963b-ecaeae206a93/edit · Plan: [`IMPLEMENTATION_PLAN.md`](../../IMPLEMENTATION_PLAN.md) (fase 9) · Composición entre capas: [ADR 0016](../../docs/adr/0016-blueprint-composition.md).

## Capas y orden de despliegue

Cada capa es un *infrastructure module* sin provider ni backend, con su propio estado en `live/<env>/<capa>` (fase 10). Las capas se comunican por SSM Parameter Store (`/<project>/<env>/<capa>/…`, ADR 0004).

| Orden | Capa | Providers | Contenido |
|---|---|---|---|
| 1 | [`network`](network/README.md) | `aws` | VPC (NAT regional; zonal en dev), endpoints de VPC (incl. `xray`), bucket de logs, CMK `platform`, topic de alarmas, DNS Firewall opcional |
| 2 | [`data`](data/README.md) | `aws`, `aws.dr` | Aurora provisionado (2 instancias en prod, Database Insights `advanced`), Valkey con IAM auth, AWS Backup `enterprise` (vault lock, copia a DR, restore testing) |
| 3 | [`app`](app/README.md) | `aws` | ECR, ECS, ALB interno + certificado regional, servicio con sidecar ADOT, bus de eventos → Firehose → data lake, alarmas, dashboard con Application Signals |
| 4 | [`edge`](edge/README.md) | `aws`, `aws.us_east_1` | Certificado del viewer, WAF (Bot Control/Anti-DDoS opcionales), cabeceras de seguridad, CloudFront con VPC origin, alarmas de borde |

## Módulos

`kms-key`, `s3-bucket`, `vpc`, `vpc-endpoints`, `dns-firewall`, `alarms`, `dashboard`, `aurora-postgresql` (+ `postgres-app-secret`), `elasticache-valkey`, `backup-plan` (×2), `ecr-repository`, `ecs-cluster`, `acm-certificate` (×2), `alb-internal`, `ecs-service`, `eventbridge-bus`, `firehose-to-s3`, `waf-web-acl`, `security-headers`, `cloudfront-vpc-origin`.

## Objetivos de resiliencia (plan 9.1.1)

| Tier | Disponibilidad diseñada | RPO | RTO |
|---|---|---|---|
| T1 | Multi-AZ activo-activo en cómputo; failover automático de Aurora | ≤ 5 min (PITR) / 24 h en la región de DR | ≤ 1 h en la región; ≤ 4–8 h en DR (redeploy por IaC + restore de la copia cross-region) |

## Valores por entorno (plan 9.2)

Las capas derivan de `environment` lo que el plan fija por entorno (cada valor se puede sobrescribir con su variable):

| Parámetro | dev | staging | prod |
|---|---|---|---|
| NAT | `zonal_single` | `regional` | `regional` |
| Aurora | 1 × `db.t4g.medium`, Insights `standard` | igual que dev | 2 × `db.r7g.large`, Insights `advanced` |
| Valkey | 1 × `cache.t4g.micro` | igual | 2 × `cache.m7g.large` |
| Backups | 7 días, sin continuo | igual | 35 días + PITR continuo, vault lock, copia a DR, restore testing |
| ECS | 1 tarea (Spot permitido), ECS Exec | 2 tareas | 2 tareas on-demand, sin ECS Exec |
| WAF | `count` | `block` | `block` |
| Retención de logs | 30 días | 30 días | 365 días |

## Notas y límites

- La cuenta debe tener antes la línea base (`foundation/account-baseline`, `live/_baseline/<cuenta>`) y, en organizaciones, los guardrails (`organization/org-guardrails`).
- Etiquetas obligatorias por `default_tags` del provider en `live/` (no dentro de las capas).
- **Pagos (alcance PCI):** checkout con campos alojados/redirect de un proveedor PCI DSS nivel 1; la tarjeta nunca toca la infraestructura (SAQ A). Procesar tarjetas directamente es otro proyecto.
- La capa `edge` admite la aplicación en cualquier región: fuera de us-east-1 la regla de entrada del ALB la crea la propia capa con el provider de la aplicación (ADR 0016).
- Los SLO de Application Signals son un paso manual del runbook (`aws application-signals create-service-level-objective`): el provider 6.67/6.68 no tiene recurso.
- RTO < 1 h ante la pérdida de una región completa se cotiza aparte (Aurora Global Database + warm standby).

## Pruebas

- Unitarias (sin coste, en `make test`): `tests/unit.tftest.hcl` de cada capa.
- Integración en la sandbox: `tests/integration.tftest.hcl` sobre [`examples/complete`](examples/complete) — aplica `network → data → app → edge` (sin copia a DR ni restore testing en la prueba) y destruye en orden inverso. Coste y procedimiento: [`docs/test-plan-sandbox.md`](../../docs/test-plan-sandbox.md).
