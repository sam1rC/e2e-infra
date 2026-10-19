# e2e-infra

Infraestructura de **e2e** con el blueprint `saas-t3` del catálogo (versión en `CATALOG_VERSION`).
Generado por `scripts/new-client.sh` desde `client.yaml`; `modules/`, `blueprints/`, `sql/`, `policies/` y
`docs/runbooks/` son una copia del catálogo: no se editan aquí (llegan como PR de re-vendorización).

## Estructura

Cada directorio de `live/` es una raíz con su propio estado (`backend.tf`), versiones fijadas (`versions.tf` +
`.terraform.lock.hcl` versionado), providers con `allowed_account_ids` y `default_tags`, y sus valores en
`<entorno>.auto.tfvars` (sin secretos).

| Raíz | Cuenta | Estado |
|---|---|---|
| `live/_bootstrap/sandbox-dev` | sandbox (`654654616677`) | local → `e2e-dev-tfstate-654654616677` |
| `live/_bootstrap/sandbox-staging` | sandbox (`654654616677`) | local → `e2e-staging-tfstate-654654616677` |
| `live/dev/stack` | sandbox (`654654616677`) | `s3://e2e-dev-tfstate-654654616677/dev/stack/terraform.tfstate` |
| `live/staging/stack` | sandbox (`654654616677`) | `s3://e2e-staging-tfstate-654654616677/staging/stack/terraform.tfstate` |

## Orden de despliegue

1. **`live/_bootstrap/*`** (una vez por cuenta y entorno, con credenciales de administrador): `tofu init && tofu apply`
   con estado local; después `mv backend.tf.migrate backend.tf && tofu init -migrate-state` y borra el estado local
   (runbook `docs/runbooks/bootstrap.md`). Los roles `plan_role_arn`/`apply_role_arn` van a los GitHub Environments.
2. **`live/_baseline/*`**: línea base de cada cuenta (CloudTrail, GuardDuty, Security Hub, Config…).
3. **`live/_org/security`** (solo SaaS T1, cuenta de management) y **`live/<env>/control-plane`**.
4. **Capas de cada entorno**, en el orden del blueprint (`network → data → app → edge`, o `stack` en T3), primero
   `dev`, luego `staging` y `prod`. Las capas se comunican por SSM (`/<project>/<env>/<capa>/…`).
5. **Tenants silo** (SaaS T1): `live/silo-<tenant>/silo` y después sus capas `app-*` (`silo-deploy.yml`).

Desde el paso 2, todo cambio pasa por la CI (`.github/`, runbook `docs/runbooks/ci-cd.md`): `plan.yml` comenta el
plan, las políticas y el coste de cada raíz cambiada en el PR; `apply.yml` aplica en `main` el plan revisado raíz a
raíz, en este orden (prod y las cuentas sensibles piden aprobación en su GitHub Environment); `drift.yml` abre un
issue diario por raíz con drift; `catalog-update.yml` abre el PR de una versión nueva del catálogo. Configura el
repositorio una vez con `scripts/github-setup.sh --repo <owner/repo> --reviewers team:<slug>`.

Antes del primer apply de cada capa revisa su `*.auto.tfvars`: los valores `REEMPLAZAR` fallan a propósito en el plan.

- **Imagen de la aplicación (T1/T2):** el ECR lo crea la capa `app`. En el primer despliegue:
  `tofu apply -target=module.<capa>.module.ecr`, publica la imagen y fija `service.image` por digest.
- **Lambdas (T3 y control plane):** sube una primera versión del zip al bucket de artefactos de `_bootstrap` antes del
  apply (`api/app.zip` u `onboarding/app.zip`).
- **SaaS T1:** `jwt_issuers` y `metering_bus_arn` de las capas `app-app` son salidas de la capa `control-plane`.

## Comandos

```bash
export TF_PLUGIN_CACHE_DIR=$HOME/.terraform.d/plugin-cache
tofu -chdir=live/dev/network init
tofu -chdir=live/dev/network plan -out=plan.tfplan     # cifrado por el bloque encryption
tofu -chdir=live/dev/network show -json plan.tfplan | conftest test -p policies/opa -
scripts/lock-providers.sh live                          # tras cambiar versiones de providers
```
