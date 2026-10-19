# Runbook — Alta de un tenant silo (SaaS T1)

Un tenant del tier premium recibe su propia cuenta AWS con el app plane completo (`live/silo-<tenant>/`). El
onboarding del control plane dispara `silo-deploy.yml` (GitHub App, salida `silo_pipeline`), pero la cuenta y las
raíces se preparan antes con este procedimiento.

1. **Cuenta.** En `client.yaml` añade la cuenta (`accounts.silo-<tenant>`, ID entre comillas), su entrada en
   `saas_t1.member_accounts` (`ou: silo`, `tenant_id`) y el tenant en `saas_t1.silo_tenants` (cuenta, dominio, zona,
   presupuesto). Si la cuenta aún no existe, el apply de `live/_org/security` la crea (PR → aprobación `management`) y
   da su ID; actualiza `accounts` con él.
2. **Raíces y CI.** Desde una copia del catálogo en la versión de `CATALOG_VERSION`:
   ```bash
   scripts/new-client.sh client.yaml <repo-del-cliente> --add-missing
   ```
   Crea `live/_bootstrap/silo-<tenant>`, `live/_baseline/silo-<tenant>` y `live/silo-<tenant>/{silo,app-*}` sin tocar las
   raíces existentes, y regenera `apply.yml`, `CODEOWNERS` y `.github/live-roots.json`.
3. **Valores que dependen de la lista de cuentas** (no se regeneran): añade el ID de la cuenta nueva a
   `app_account_ids` de `live/<env>/control-plane/*.auto.tfvars` (metering) y, si no lo hiciste en el paso 1, a
   `accounts` de `live/_org/security`.
4. **Bootstrap** de la cuenta (runbook `bootstrap`, con `assume_role` a `OrganizationAccountAccessRole` desde
   management si hace falta) y `scripts/github-setup.sh` para crear el environment `silo-<tenant>`.
5. **PR** con todo lo anterior. Tras el merge, `apply.yml` aplica la línea base y las capas del tenant (con la
   aprobación del environment), o lanza `silo-deploy.yml` con `tenant_id`.
6. **Verificación**: la aplicación del tenant responde en su dominio; el tenant está en el registro del control plane
   con modelo `silo`; los eventos de metering llegan al bus del control plane.

## Baja
La baja destruye datos: requiere la etiqueta `allow-destroy`, un backup final verificado y retirar el tenant de
`client.yaml` y de `live/`. La cuenta se cierra desde Organizations (queda suspendida 90 días).
