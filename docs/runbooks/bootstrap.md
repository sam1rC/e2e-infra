# Runbook — Bootstrap de estado remoto e identidad de CI

Se ejecuta **una vez por cuenta/entorno**, con credenciales de administrador (humanas, vía IAM Identity Center). Después, todo cambio pasa por CI.

## Requisitos
- OpenTofu 1.11.x (`.tool-versions`), AWS CLI y acceso de administrador a la cuenta.
- Repositorio del cliente creado en GitHub; GitHub Environment `<env>` creado (en `prod`: revisores obligatorios y restricción de ramas a `main`).

## Pasos

0. **Subject de OIDC del repositorio.** Los repositorios nuevos de GitHub emiten un `sub` inmutable con los IDs del
   propietario y del repositorio (`repo:<org>@<id>/<repo>@<id>:...`). Crea el repositorio antes del bootstrap y
   copia su prefijo a `client.yaml` (`github.subject_prefix`, o `github_subject_prefix` en el `*.auto.tfvars`):
   ```bash
   gh api repos/<org>/<repo>/actions/oidc/customization/sub --jq .sub_claim_prefix
   ```
   Sin él, los roles confían en `repo:<org>/<repo>` y GitHub Actions recibe `Not authorized to perform
   sts:AssumeRoleWithWebIdentity` (encontrado en el E2E del 2026-10-19).

1. **Aplicar con estado local.** En `live/_bootstrap/<cuenta>[-<env>]/` (generado por `scripts/new-client.sh`: `state-backend`, `github-oidc` y, en T3 y en el control plane de SaaS T1, el bucket de artefactos de Lambda; sin `backend.tf`):
   ```bash
   tofu init
   tofu apply
   ```
   Anota los outputs `backend_config`, `plan_role_arn` y `apply_role_arn`.
   Si la cuenta ya tiene el proveedor OIDC de GitHub, pon `create_oidc_provider = false` (el generador ya lo hace en el segundo entorno de una cuenta compartida).

2. **Migrar el estado al bucket.** `backend.tf.migrate` es el backend definitivo más un método `unencrypted` como
   `fallback` y `enforced = false`: sin él, OpenTofu no puede leer el estado local sin cifrar para subirlo
   (`encountered unencrypted payload without unencrypted method configured`; y con `enforced = true` rechaza el método
   `unencrypted`). Comprobado en la sandbox el 2026-10-19:
   ```bash
   cp backend.tf.migrate backend.tf
   tofu init -migrate-state -force-copy
   ```
   El estado se sube ya cifrado con la CMK de estado.

3. **Configuración definitiva y verificación.**
   ```bash
   mv backend.tf.final backend.tf && rm backend.tf.migrate
   tofu init && tofu plan -detailed-exitcode        # exit 0: lee el estado cifrado, sin cambios
   aws s3 cp s3://<bucket>/<env>/bootstrap/terraform.tfstate - | jq 'keys'
   ```
   El objeto solo debe tener `encrypted_data`, `encryption_version`, `lineage`, `meta` y `serial` (sin `resources`).
   `aws s3api head-object` debe mostrar además `ServerSideEncryption: aws:kms` con la CMK de estado.

4. **Borrar el estado local** (`terraform.tfstate` y `.backup` en claro: no lo subas al repositorio).
   ```bash
   rm -f terraform.tfstate terraform.tfstate.backup && rm -rf .terraform
   ```

5. **Comprobar los roles de CI.**
   - Un workflow en un PR asume `gha-plan-<env>` y ejecuta `tofu plan`.
   - Un workflow en una rama que no despliega al GitHub Environment **no** puede asumir `gha-apply-<env>` (`AccessDenied` en `AssumeRoleWithWebIdentity`).

## Cambios posteriores a `state-backend` o `github-oidc`
La boundary del rol de apply impide modificar el bucket/clave de estado y los propios roles de CI. Esos cambios se aplican con credenciales de administrador (*break-glass*), no desde CI.

## Recuperación
- Versiones anteriores del estado: `aws s3api list-object-versions --bucket <bucket> --prefix <env>/<layer>/`; restaurar copiando una versión anterior sobre la actual.
- La clave KMS de estado no se puede perder: guarda la política y el alias; el borrado programado tarda 30 días en completarse.
