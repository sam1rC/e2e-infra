# Blueprint SaaS T2 (Growth)

SaaS multi-tenant en una cuenta por entorno: las capas de E-commerce T2 (ECS + RDS PostgreSQL Multi-AZ) más un user pool compartido de tenants, datos en S3 con un prefijo por tenant y el rol ABAC que la aplicación asume por tenant. PostgreSQL en modelo bridge (esquema y rol por tenant).

Diagrama (v2): https://lucid.app/lucidchart/1ca92a47-39ba-48f1-9bc6-9e88d8c8acb6/edit · Plan: [`IMPLEMENTATION_PLAN.md`](../../IMPLEMENTATION_PLAN.md) (fase 9) · Composición entre capas: [ADR 0016](../../docs/adr/0016-blueprint-composition.md).

## Capas y orden de despliegue

Cada capa es un *infrastructure module* sin provider ni backend, con su propio estado en `live/<env>/<capa>` (fase 10). Las capas se comunican por SSM Parameter Store (`/<project>/<env>/<capa>/…`, ADR 0004).

| Orden | Capa | Providers | Contenido |
|---|---|---|---|
| 1 | [`network`](network/README.md) | `aws` | = `ecommerce-t2/network` |
| 2 | [`data`](data/README.md) | `aws` | = `ecommerce-t2/data` |
| 3 | [`app`](app/README.md) | `aws` | `ecommerce-t2/app` + Cognito compartido, bucket de tenants, rol ABAC |
| 4 | [`edge`](edge/README.md) | `aws`, `aws.us_east_1` | = `ecommerce-t2/edge` |

## Módulos

Los de E-commerce T2 más `cognito-user-pool`, `tenant-access-role` y un `s3-bucket` de datos de tenants.

## Objetivos de resiliencia (plan 9.1.1)

| Tier | Disponibilidad diseñada | RPO | RTO |
|---|---|---|---|
| T2 | Multi-AZ en cómputo y en RDS | ≤ 5 min (PITR) | ≤ 1–2 h |

## Valores por entorno (plan 9.2)

Las capas derivan de `environment` lo que el plan fija por entorno (cada valor se puede sobrescribir con su variable):

Los de E-commerce T2.

## Notas y límites

- La cuenta debe tener antes la línea base (`foundation/account-baseline`, `live/_baseline/<cuenta>`) y, en organizaciones, los guardrails (`organization/org-guardrails`).
- Etiquetas obligatorias por `default_tags` del provider en `live/` (no dentro de las capas).
- El SQL de bridge (`sql/bridge-schema-per-tenant.sql`) lo ejecuta el onboarding de cada tenant con el usuario maestro, no OpenTofu.
- La capa `edge` admite la aplicación en cualquier región: fuera de us-east-1 la regla de entrada del ALB la crea la propia capa con el provider de la aplicación (ADR 0016).

## Pruebas

- Unitarias (sin coste, en `make test`): `tests/unit.tftest.hcl` de cada capa.
- Integración en la sandbox: `tests/integration.tftest.hcl` sobre [`examples/complete`](examples/complete) — aplica `network → data → app → edge` y destruye en orden inverso. Coste y procedimiento: [`docs/test-plan-sandbox.md`](../../docs/test-plan-sandbox.md).
