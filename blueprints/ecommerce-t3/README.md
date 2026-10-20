# Blueprint E-commerce T3 (Starter)

Tienda serverless en una sola capa: frontend estático en S3 + CloudFront, API HTTP con Lambda fuera de VPC en `/api/*`, clientes en Cognito, bus de eventos y base de datos DynamoDB (opción A, por defecto) o Aurora Serverless v2 con RDS Data API (opción B).

Diagrama (v2): https://lucid.app/lucidchart/fefe40ec-ddca-483a-963b-ecaeae206a93/edit · Plan: [`IMPLEMENTATION_PLAN.md`](../../IMPLEMENTATION_PLAN.md) (fase 9) · Composición entre capas: [ADR 0016](../../docs/adr/0016-blueprint-composition.md).

## Capas y orden de despliegue

Cada capa es un *infrastructure module* sin provider ni backend, con su propio estado en `live/<env>/<capa>` (fase 10). Las capas se comunican por SSM Parameter Store (`/<project>/<env>/<capa>/…`, ADR 0004).

| Orden | Capa | Providers | Contenido |
|---|---|---|---|
| 1 | [`stack`](stack/README.md) | `aws`, `aws.us_east_1` | Todo el blueprint: CMK, Cognito, Lambda + HTTP API, bus, DynamoDB o (VPC solo de datos + Aurora Serverless v2), AWS Backup, WAF/plan flat-rate, CloudFront + S3, alarmas y dashboard |

## Módulos

`kms-key` (×3), `cognito-user-pool`, `lambda-function`, `apigw-http`, `eventbridge-bus`, `dynamodb-table` **o** `vpc` + `vpc-endpoints` + `aurora-postgresql` + `s3-bucket`, `backup-plan`, `acm-certificate`, `waf-web-acl`, `security-headers`, `s3-bucket`, `cloudfront-static-site`, `alarms` (×2), `dashboard`.

## Objetivos de resiliencia (plan 9.1.1)

| Tier | Disponibilidad diseñada | RPO | RTO |
|---|---|---|---|
| T3 | Servicios regionales gestionados (multi-AZ por diseño) | ≤ 5 min (PITR de DynamoDB/Aurora) | ≤ 2–4 h (PITR + redeploy) |

## Valores por entorno (plan 9.2)

Las capas derivan de `environment` lo que el plan fija por entorno (cada valor se puede sobrescribir con su variable):

| Parámetro | dev / staging | prod |
|---|---|---|
| Aurora (opción B) | Serverless v2 con auto-pausa (`min_capacity = 0`) | `min_capacity = 0.5`, 2 instancias |
| Backups | 7 días, sin continuo | 35 días + PITR continuo |
| WAF | `count` (dev) / `block` (staging) | `block` |
| Retención de logs | 30 días | 365 días |
| Cognito | MFA opcional, correo de Cognito | MFA obligatoria, correo por SES |

## Notas y límites

- La cuenta debe tener antes la línea base (`foundation/account-baseline`, `live/_baseline/<cuenta>`) y, en organizaciones, los guardrails (`organization/org-guardrails`).
- Etiquetas obligatorias por `default_tags` del provider en `live/` (no dentro de las capas).
- El token `x-origin-verify` (ADR 0010) se rota subiendo `origin_verify_version`: la Lambda acepta el valor actual y el anterior.
- El plan flat-rate de CloudFront (`waf_mode = "flat_rate"`) se contrata en la consola: paso manual del runbook.
- `spa_error_codes` reescribe también los 403/404 de `/api/*` como `index.html`: vacíalo si el frontend no es una SPA.

## Pruebas

- Unitarias (sin coste, en `make test`): `tests/unit.tftest.hcl` de cada capa.
- Integración en la sandbox: `tests/integration.tftest.hcl` sobre [`examples/complete`](examples/complete) — aplica la capa `stack` con DynamoDB y la destruye. Coste y procedimiento: [`docs/test-plan-sandbox.md`](../../docs/test-plan-sandbox.md).
