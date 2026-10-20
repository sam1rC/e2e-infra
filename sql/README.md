# sql/ — bootstrap de PostgreSQL (fase 8.4)

OpenTofu **no** gestiona objetos dentro de PostgreSQL (evita abrir red desde CI hacia la base). Estas plantillas las ejecuta el proceso de onboarding del cliente con `psql` desde dentro de la VPC (tarea ECS de un solo uso, Session Manager o CloudShell en VPC), **por TLS** y con el usuario maestro, cuyo secreto gestiona RDS. Requieren PostgreSQL ≥ 16 (`GRANT … WITH INHERIT/SET`); el catálogo usa 17.

| Script | Cuándo | Qué hace |
|---|---|---|
| [`00-app-runtime.sql`](00-app-runtime.sql) | Una vez por base de datos (todos los tiers con PostgreSQL) | Roles `app_owner` (NOLOGIN, dueño de esquemas y tablas, solo migraciones) y `app_runtime` (LOGIN **sin contraseña**, sin administración ni `BYPASSRLS`, no es dueño de nada); esquema `app`; privilegios por defecto; nada en `public`. |
| [`pool-rls.sql`](pool-rls.sql) | Una vez, en el modelo **Pool** (SaaS T1) | Procedimiento `app.enable_tenant_rls(tabla)` que las migraciones llaman por cada tabla de tenants: `ENABLE` + `FORCE ROW LEVEL SECURITY` y política `tenant_isolation` que **falla cerrado** sin contexto. |
| [`bridge-schema-per-tenant.sql`](bridge-schema-per-tenant.sql) | En el onboarding de cada tenant, modelo **Bridge** (SaaS T2), y tras migraciones que creen tablas | Rol `tenant_<id>` (NOLOGIN) y esquema `tenant_<id>`; `app_runtime` puede hacer `SET LOCAL ROLE tenant_<id>` pero **no hereda** sus privilegios. |

Las tres son idempotentes. Reglas de modelado y del contexto de tenant: [ADR 0006](../docs/adr/0006-pool-isolation.md) y [ADR 0009](../docs/adr/0009-tenant-context-transaction-scoped.md).

## Orden de ejecución

```bash
# 0. Conexión TLS verificada (bundle de CA de RDS: https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem)
export PGSSLMODE=verify-full PGSSLROOTCERT=global-bundle.pem
MASTER=$(aws secretsmanager get-secret-value --secret-id "$MASTER_SECRET_ARN" --query SecretString --output text)
export PGUSER=$(jq -r .username <<<"$MASTER") PGPASSWORD=$(jq -r .password <<<"$MASTER") PGHOST=$WRITER_ENDPOINT PGDATABASE=app

# 1. Roles y esquema base
psql -v ON_ERROR_STOP=1 -f sql/00-app-runtime.sql

# 2a. Pool: procedimiento de RLS (luego, en cada migración: CALL app.enable_tenant_rls('app.<tabla>');)
psql -v ON_ERROR_STOP=1 -f sql/pool-rls.sql
# 2b. Bridge: un esquema por tenant (id: minúsculas, dígitos y _)
psql -v ON_ERROR_STOP=1 -v tenant_id=acme_corp -f sql/bridge-schema-per-tenant.sql

unset PGPASSWORD
```

## Credenciales de la aplicación (`app_runtime`)

`app_runtime` se crea **sin contraseña**: la fija la rotación multiusuario de Secrets Manager (`data/postgres-app-secret`), de modo que ninguna contraseña pasa por estos scripts, el historial de `psql` ni los logs de errores. La función oficial de AWS, en su primera rotación, crea `app_runtime_clone` con una contraseña nueva usando el secreto maestro y ejecuta `GRANT app_runtime TO app_runtime_clone`; en las siguientes alterna `ALTER USER … WITH PASSWORD` entre ambos usuarios. Los privilegios, la pertenencia a `tenant_<id>` (Bridge) y las políticas RLS (Pool) aplican igual a los dos (comprobado localmente, ver abajo). `pgaudit` (`pgaudit.log = 'ddl,role'` en los módulos de la fase 6) redacta las contraseñas de `CREATE/ALTER ROLE` (`PASSWORD <REDACTED>`).

Tras el paso 1, inicializa el secreto y fuerza la primera rotación:

```bash
# La función exige las claves host, username, password y engine; la contraseña inicial es un marcador que
# nunca se usa (app_runtime no tiene contraseña hasta que la rotación la fija).
aws secretsmanager put-secret-value --secret-id "$APP_SECRET_ARN" --secret-string "$(jq -n \
  --arg host "$WRITER_ENDPOINT" --arg db app --arg master "$MASTER_SECRET_ARN" --arg pw "$(openssl rand -hex 24)" \
  '{engine:"postgres", host:$host, port:5432, dbname:$db, username:"app_runtime", password:$pw, masterarn:$master}')"
aws secretsmanager rotate-secret --secret-id "$APP_SECRET_ARN"
```

La aplicación lee **siempre** el secreto (`username` puede ser `app_runtime` o `app_runtime_clone`) y no debe depender de ajustes por rol (`ALTER ROLE … SET`): el usuario clonado no los hereda. Fija `search_path` y `statement_timeout` en la cadena de conexión.

## Uso desde la aplicación

```sql
-- Pool: contexto local a la transacción (set_config(..., true)); el pool ejecuta RESET ALL al devolver la conexión.
BEGIN;
SELECT set_config('app.current_tenant', $1, true);   -- $1 = tenant_id (uuid) del JWT validado
SELECT ... FROM app.orders ...;
COMMIT;

-- Bridge: rol del tenant solo durante la transacción.
BEGIN;
SET LOCAL ROLE tenant_acme_corp;                      -- identificador validado contra ^[a-z0-9_]{1,40}$
SET LOCAL search_path = tenant_acme_corp;
SELECT ... FROM orders ...;
COMMIT;
```

No uses RDS Proxy con estos patrones sin evaluarlo: los cambios de estado de sesión provocan *pinning* (ADR 0009). `FORCE ROW LEVEL SECURITY` también aplica al dueño: las migraciones que muevan datos de tenants fijan el contexto igual que la aplicación.

## Cómo se verificó

[`tests/integration/tenant-isolation/postgres.sh`](../tests/integration/tenant-isolation/postgres.sh) levanta PostgreSQL 17 en Docker (sin AWS ni coste), crea un maestro **sin superusuario** con `CREATEROLE`/`CREATEDB` (como el de RDS), ejecuta los tres scripts (dos veces, para comprobar la idempotencia), simula la rotación con las mismas sentencias que la función de AWS y lanza [`postgres-isolation.sql`](../tests/integration/tenant-isolation/postgres-isolation.sql) como `app_runtime_clone` y como `app_runtime`: sin contexto 0 filas, el tenant A no ve ni escribe ni reasigna filas de B, la reutilización de la conexión tras el `COMMIT` no conserva el tenant (Pool: 0 filas; Bridge: `permission denied`), un contexto que no es uuid aborta, y la aplicación no puede desactivar RLS ni crear tablas. **Controles negativos**: con `GRANT … WITH INHERIT TRUE` en Bridge, o con una política que deja pasar todo en Pool, la prueba falla.

Esa ejecución local detectó que el maestro de RDS no puede nombrar `NOSUPERUSER`/`NOREPLICATION`/`NOBYPASSRLS` en `ALTER ROLE` (solo un superusuario puede): los scripts los comprueban en lugar de fijarlos. **Pendiente en sandbox:** repetir la prueba contra Aurora/RDS con la rotación real (que la función cree el clon y que `SET LOCAL ROLE` funcione a través de `app_runtime_clone → app_runtime → tenant_<id>`).
