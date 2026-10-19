# Runbook — Bootstrap de estado remoto e identidad de CI

Se ejecuta **una vez por cuenta/entorno**, con credenciales de administrador (humanas, vía IAM Identity Center). Después, todo cambio pasa por CI.

## Requisitos
- OpenTofu 1.11.x (`.tool-versions`), AWS CLI y acceso de administrador a la cuenta.
- Repositorio del cliente creado en GitHub; GitHub Environment `<env>` creado (en `prod`: revisores obligatorios y restricción de ramas a `main`).

## Pasos

1. **Aplicar con estado local.** En `live/_bootstrap/<cuenta>[-<env>]/` (generado por `scripts/new-client.sh`: `state-backend`, `github-oidc` y, en T3 y en el control plane de SaaS T1, el bucket de artefactos de Lambda; sin `backend.tf`):
   ```bash
   tofu init
   tofu apply
   ```
   Anota los outputs `backend_config`, `plan_role_arn` y `apply_role_arn`.
   Si la cuenta ya tiene el proveedor OIDC de GitHub, pon `create_oidc_provider = false` (el generador ya lo hace en el segundo entorno de una cuenta compartida).

2. **Migrar el estado al bucket.** Renombra el `backend.tf.migrate` generado a `backend.tf` (es el mismo bloque que el output `backend_config` con `<layer>` = `bootstrap`; compruébalo) y ejecuta:
   ```bash
   tofu init -migrate-state
   ```
   Responde `yes` a la copia del estado local. El bloque `encryption` cifrará el estado antes de subirlo.

3. **Verificar que el estado remoto está cifrado.**
   ```bash
   aws s3 cp s3://<bucket>/<env>/bootstrap/terraform.tfstate - | head -c 300
   ```
   No debe ser JSON legible (OpenTofu lo cifra con AES-GCM antes de subirlo). Comprueba además `aws s3api head-object` → `ServerSideEncryption: aws:kms`.

4. **Borrar el estado local.**
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
