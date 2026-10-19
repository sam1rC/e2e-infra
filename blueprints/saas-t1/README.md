# Blueprint SaaS T1 (Enterprise, multi-cuenta)

SaaS multi-tenant con separación de funciones por cuenta (management, security, log-archive, control-plane, app-nonprod, app-prod y una cuenta por tenant silo): control plane con identidad, registro, onboarding y metering; app plane que reutiliza las capas de E-commerce T1 con aislamiento pool/bridge en Aurora y silo por cuenta para los tenants premium.

Diagrama (v2): https://lucid.app/lucidchart/1ca92a47-39ba-48f1-9bc6-9e88d8c8acb6/edit · Plan: [`IMPLEMENTATION_PLAN.md`](../../IMPLEMENTATION_PLAN.md) (fase 9) · Composición entre capas: [ADR 0016](../../docs/adr/0016-blueprint-composition.md).

## Capas y orden de despliegue

Cada capa es un *infrastructure module* sin provider ni backend, con su propio estado en `live/<env>/<capa>` (fase 10). Las capas se comunican por SSM Parameter Store (`/<project>/<env>/<capa>/…`, ADR 0004).

| Orden | Capa | Cuenta | Providers | Contenido |
|---|---|---|---|---|
| 1 | [`security`](security/README.md) | management | `aws` | OU, cuentas miembro, SCP por OU, administración delegada en `security` |
| — | `account-baseline` | cada cuenta | `aws` | Fase 2, en `live/_baseline/<cuenta>` (no es una capa del blueprint) |
| 2 | [`control-plane`](control-plane/README.md) | control-plane | `aws` | User pools (por tier o por tenant), registro, onboarding, bus + metering por tenant, backup |
| 3 | [`app-network`](app-network/README.md) | app-* / silo | `aws` | = `ecommerce-t1/network` |
| 4 | [`app-data`](app-data/README.md) | app-* / silo | `aws`, `aws.dr` | = `ecommerce-t1/data` (Valkey opcional) |
| 5 | [`app-app`](app-app/README.md) | app-* / silo | `aws` | `ecommerce-t1/app` + rol ABAC, bucket de tenants, JWT del control plane, metering |
| 6 | [`app-edge`](app-edge/README.md) | app-* / silo | `aws`, `aws.us_east_1` | = `ecommerce-t1/edge` |
| — | [`silo`](silo/README.md) | silo-&lt;tenant&gt; | `aws` | CMK del tenant, rol de despliegue, presupuesto (antes de las capas `app-*` del tenant) |

## Módulos

`org-account`, `org-guardrails`, `cross-account-role`, `budgets`, `cognito-user-pool`, `dynamodb-table`, `lambda-function`, `eventbridge-bus`, `firehose-to-s3`, `tenant-access-role` y todo lo de E-commerce T1.

## Objetivos de resiliencia (plan 9.1.1)

| Tier | Disponibilidad diseñada | RPO | RTO |
|---|---|---|---|
| T1 | Multi-AZ activo-activo en cómputo; failover automático de Aurora | ≤ 5 min (PITR) / 24 h en la región de DR | ≤ 1 h en la región; ≤ 4–8 h en DR (redeploy por IaC + restore de la copia cross-region) |

## Valores por entorno (plan 9.2)

Las capas derivan de `environment` lo que el plan fija por entorno (cada valor se puede sobrescribir con su variable):

Como E-commerce T1 en las capas `app-*`. El control plane usa los mismos criterios (retenciones, vault lock en prod, MFA `ON` y correo por SES en prod). En la cuenta de un tenant silo, `app-app` usa `isolation_model = "silo"` y `tenant_id`.

## Notas y límites

- La cuenta debe tener antes la línea base (`foundation/account-baseline`, `live/_baseline/<cuenta>`) y, en organizaciones, los guardrails (`organization/org-guardrails`).
- Etiquetas obligatorias por `default_tags` del provider en `live/` (no dentro de las capas).
- Prerrequisito: AWS Organizations (recomendado Control Tower) con el acceso de confianza de GuardDuty, Security Hub, Config, Access Analyzer e Inspector.
- Un directorio de `live/` por tenant silo (blast radius mínimo); el onboarding de un silo dispara el pipeline (GitHub Actions `workflow_dispatch` con una GitHub App) en lugar de crear infraestructura desde Lambda.
- Aislamiento en Aurora: pool (RLS, `sql/pool-rls.sql`) o bridge (`sql/bridge-schema-per-tenant.sql`) con contexto por transacción (ADR 0006, 0009).
- El app plane valida los JWT de los pools del control plane (variables `jwt_issuers`) y publica el uso en su bus (`metering_bus_arn`), autorizado por `app_account_ids`.

## Pruebas

- Unitarias (sin coste, en `make test`): `tests/unit.tftest.hcl` de cada capa.
- Integración en la sandbox: `tests/integration.tftest.hcl` sobre [`examples/complete`](examples/complete) — aplica `control-plane → app-network → app-data → app-app → app-edge` en una sola cuenta; `security` y `silo` se validan con `plan` (la sandbox no pertenece a una organización). Coste y procedimiento: [`docs/test-plan-sandbox.md`](../../docs/test-plan-sandbox.md).
