# Blueprint E-commerce T2 (Growth)

Como T1 con menos piezas: una NAT zonal, RDS PostgreSQL (Multi-AZ en prod) en lugar de Aurora, sin Valkey, sin eventos ni DNS Firewall, y AWS Backup sin copia entre regiones.

Diagrama (v2): https://lucid.app/lucidchart/fefe40ec-ddca-483a-963b-ecaeae206a93/edit · Plan: [`IMPLEMENTATION_PLAN.md`](../../IMPLEMENTATION_PLAN.md) (fase 9) · Composición entre capas: [ADR 0016](../../docs/adr/0016-blueprint-composition.md).

## Capas y orden de despliegue

Cada capa es un *infrastructure module* sin provider ni backend, con su propio estado en `live/<env>/<capa>` (fase 10). Las capas se comunican por SSM Parameter Store (`/<project>/<env>/<capa>/…`, ADR 0004).

| Orden | Capa | Providers | Contenido |
|---|---|---|---|
| 1 | [`network`](network/README.md) | `aws` | VPC con una NAT zonal, endpoints de VPC, bucket de logs, CMK `platform`, topic de alarmas |
| 2 | [`data`](data/README.md) | `aws` | RDS PostgreSQL (Multi-AZ en prod), AWS Backup `growth` (vault lock en prod) |
| 3 | [`app`](app/README.md) | `aws` | ECR, ECS, ALB interno + certificado regional, servicio Fargate, alarmas y dashboard |
| 4 | [`edge`](edge/README.md) | `aws`, `aws.us_east_1` | Certificado del viewer, WAF, cabeceras de seguridad, CloudFront con VPC origin, alarmas de borde |

## Módulos

`kms-key`, `s3-bucket`, `vpc`, `vpc-endpoints`, `alarms`, `dashboard`, `rds-postgresql` (+ `postgres-app-secret`), `backup-plan`, `ecr-repository`, `ecs-cluster`, `acm-certificate` (×2), `alb-internal`, `ecs-service`, `waf-web-acl`, `security-headers`, `cloudfront-vpc-origin`.

## Objetivos de resiliencia (plan 9.1.1)

| Tier | Disponibilidad diseñada | RPO | RTO |
|---|---|---|---|
| T2 | Multi-AZ en cómputo y en RDS | ≤ 5 min (PITR) | ≤ 1–2 h |

## Valores por entorno (plan 9.2)

Las capas derivan de `environment` lo que el plan fija por entorno (cada valor se puede sobrescribir con su variable):

| Parámetro | dev | staging | prod |
|---|---|---|---|
| RDS | `db.t4g.micro`, Single-AZ | igual | `db.m7g.large`, Multi-AZ |
| Backups | 7 días, sin continuo | igual | 35 días + PITR continuo, vault lock |
| ECS | 1 tarea (Spot permitido), ECS Exec | 1 tarea | 2 tareas on-demand, sin ECS Exec |
| WAF | `count` | `block` | `block` |
| Retención de logs | 30 días | 30 días | 365 días |

## Notas y límites

- La cuenta debe tener antes la línea base (`foundation/account-baseline`, `live/_baseline/<cuenta>`) y, en organizaciones, los guardrails (`organization/org-guardrails`).
- Etiquetas obligatorias por `default_tags` del provider en `live/` (no dentro de las capas).
- **Pagos (alcance PCI):** igual que T1 (SAQ A).
- La capa `edge` admite la aplicación en cualquier región: fuera de us-east-1 la regla de entrada del ALB la crea la propia capa con el provider de la aplicación (ADR 0016).

## Pruebas

- Unitarias (sin coste, en `make test`): `tests/unit.tftest.hcl` de cada capa.
- Integración en la sandbox: `tests/integration.tftest.hcl` sobre [`examples/complete`](examples/complete) — aplica `network → data → app → edge` y destruye en orden inverso. Coste y procedimiento: [`docs/test-plan-sandbox.md`](../../docs/test-plan-sandbox.md).
