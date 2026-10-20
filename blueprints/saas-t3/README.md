# Blueprint SaaS T3 (Starter, pool serverless)

SaaS multi-tenant serverless en una sola capa: frontend estático + CloudFront, REST API con autorizador de Cognito, API key por tenant y planes de uso por tier, WAF regional que solo acepta tráfico de CloudFront, Lambda que asume un rol ABAC por tenant y tabla DynamoDB particionada por `tenant_id`.

Diagrama (v2): https://lucid.app/lucidchart/1ca92a47-39ba-48f1-9bc6-9e88d8c8acb6/edit · Plan: [`IMPLEMENTATION_PLAN.md`](../../IMPLEMENTATION_PLAN.md) (fase 9) · Composición entre capas: [ADR 0016](../../docs/adr/0016-blueprint-composition.md).

## Capas y orden de despliegue

Cada capa es un *infrastructure module* sin provider ni backend, con su propio estado en `live/<env>/<capa>` (fase 10). Las capas se comunican por SSM Parameter Store (`/<project>/<env>/<capa>/…`, ADR 0004).

| Orden | Capa | Providers | Contenido |
|---|---|---|---|
| 1 | [`stack`](stack/README.md) | `aws`, `aws.us_east_1` | Todo el blueprint |

## Módulos

`kms-key` (×3), `cognito-user-pool`, `dynamodb-table`, `lambda-function`, `tenant-access-role`, `waf-web-acl` (×2), `apigw-rest`, `backup-plan`, `acm-certificate`, `security-headers`, `s3-bucket`, `cloudfront-static-site`, `alarms` (×2), `dashboard`.

## Objetivos de resiliencia (plan 9.1.1)

| Tier | Disponibilidad diseñada | RPO | RTO |
|---|---|---|---|
| T3 | Servicios regionales gestionados (multi-AZ por diseño) | ≤ 5 min (PITR de DynamoDB/Aurora) | ≤ 2–4 h (PITR + redeploy) |

## Valores por entorno (plan 9.2)

Las capas derivan de `environment` lo que el plan fija por entorno (cada valor se puede sobrescribir con su variable):

| Parámetro | dev / staging | prod |
|---|---|---|
| Backups | 7 días, sin continuo | 35 días + PITR continuo |
| WAF (CloudFront y regional) | `count` (dev) / `block` (staging) | `block` |
| Retención de logs | 30 días | 365 días |
| Cognito | MFA opcional, correo de Cognito | MFA obligatoria, correo por SES |

## Notas y límites

- La cuenta debe tener antes la línea base (`foundation/account-baseline`, `live/_baseline/<cuenta>`) y, en organizaciones, los guardrails (`organization/org-guardrails`).
- Etiquetas obligatorias por `default_tags` del provider en `live/` (no dentro de las capas).
- `manage_apigw_account_logging_role` crea el rol de CloudWatch de API Gateway de la cuenta/región: ponlo en `false` si otra pila ya lo gestiona.
- Rotar `x-origin-verify` (`origin_verify_version`) cambia a la vez CloudFront y el WAF regional: hay una ventana de rechazo de minutos mientras CloudFront propaga (hacerlo fuera de horas).

## Pruebas

- Unitarias (sin coste, en `make test`): `tests/unit.tftest.hcl` de cada capa.
- Integración en la sandbox: `tests/integration.tftest.hcl` sobre [`examples/complete`](examples/complete) — aplica la capa `stack` y la destruye. Coste y procedimiento: [`docs/test-plan-sandbox.md`](../../docs/test-plan-sandbox.md).
