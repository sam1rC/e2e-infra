# Runbook — CI/CD del repositorio de infraestructura

Workflows de `.github/workflows/` generados por `scripts/new-client.sh` (ADR 0018). Todo cambio en la infraestructura
pasa por un PR; nadie aplica desde su portátil salvo el bootstrap y los casos *break-glass*.

## Puesta en marcha (una vez)

1. **Bootstrap de cada cuenta/entorno** (runbook `bootstrap`): crea el bucket de estado y los roles `gha-plan-<env>`
   y `gha-apply-<env>` que usa la CI.
2. **Configurar el repositorio** con un administrador:
   ```bash
   scripts/github-setup.sh --repo <owner>/<repo> --reviewers team:<equipo-aprobador> \
     --catalog-repository <owner>/<catalogo>            # --dry-run para ver las llamadas
   ```
   Crea un GitHub Environment por cada entrada de `.github/live-roots.json` (todos salvo `dev` y `staging` con
   revisores obligatorios y sin autoaprobación; solo despliegan desde ramas protegidas), protege `main` (PR, 1
   aprobación, CODEOWNERS, check `plan-result`) y crea las etiquetas `allow-destroy` y `drift`.
3. **Secretos** (Settings → Secrets): `CATALOG_READ_TOKEN` (lectura del catálogo, para `catalog-update`); opcionales
   `CATALOG_UPDATE_TOKEN` (para que el PR de actualización dispare el plan) e `INFRACOST_API_KEY`.

## Flujo normal

| Evento | Workflow | Qué hace |
|---|---|---|
| PR | `plan.yml` | fmt/tflint/trivy/checkov de `live/`; plan + conftest (+ Infracost) de cada raíz cambiada; un comentario por raíz |
| merge a `main` | `apply.yml` | por raíz cambiada y en orden: plan (rol de plan) → apply de ese plan (rol de apply, en su environment) |
| cada día 05:17 UTC | `drift.yml` | plan de todas las raíces; issue `Drift detectado: live/<raíz>` si difieren |
| manual | `catalog-update.yml` | vendoriza la versión pedida del catálogo y abre un PR con su CHANGELOG |
| manual / onboarding | `silo-deploy.yml` | despliega las capas de un tenant silo (SaaS T1) |

- **Prod pide aprobación**: el job `apply live/prod/...` queda en *Waiting* hasta que un revisor lo aprueba en la
  pestaña Actions. Revisa antes el plan del resumen del job (es el que se aplicará).
- **Plan obsoleto**: si otra ejecución cambió el estado entre el plan y el apply, `tofu apply` lo rechaza. Relanza el
  workflow (*Re-run all jobs*): genera un plan nuevo.
- **Destrucción de recursos con estado**: conftest bloquea el plan. Si es intencional, añade la etiqueta
  `allow-destroy` al PR (el plan se repite) y deja constancia en la descripción. `apply.yml` lee la etiqueta del PR
  fusionado y aplica con la misma excepción; un `workflow_dispatch` nunca la tiene. Además, los recursos con
  `deletion_protection`/`prevent_destroy` necesitan un PR previo que la desactive.
- **Apply manual de todo**: `apply.yml` → *Run workflow* planifica todas las raíces y aplica las que tienen cambios.

## Drift

1. Abre el issue y su ejecución: el plan muestra qué difiere.
2. Si el cambio manual era correcto, llévalo al código en un PR; si no, relanza `apply.yml` (*Run workflow*) para
   revertirlo.
3. El issue se cierra solo en la siguiente ejecución sin drift.

## Actualizar el catálogo

1. Actions → `catalog-update` → *Run workflow* con la versión (`X.Y.Z`).
2. Revisa el PR: CHANGELOG, plan y políticas de cada raíz (un cambio en `modules/` o `blueprints/` planifica todas).
3. Las variables nuevas de las capas no aparecen en los `*.auto.tfvars`: consulta el README de cada capa. Los
   workflows y raíces nuevas se regeneran con `new-client.sh --add-missing` desde el catálogo.

## Problemas frecuentes

- `Not authorized to perform sts:AssumeRoleWithWebIdentity`: el subject del token no coincide con la trust policy.
  Mira el `userName` del evento fallido en el historial de CloudTrail (`aws cloudtrail lookup-events
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity`): si es
  `repo:<org>@<id>/<repo>@<id>:...`, fija `github_subject_prefix` en el bootstrap (runbook `bootstrap`, paso 0). Si no,
  el job de apply no está en el GitHub Environment que espera el rol o el plan se lanzó desde otra rama.
- `the lock file ... does not contain hashes for linux_amd64`: regenera los locks con `scripts/lock-providers.sh live`.
- `Error acquiring the state lock`: otra ejecución tiene el lock; espera (`-lock-timeout=10m`). Si quedó huérfano,
  `tofu force-unlock <ID>` con credenciales de administrador.
