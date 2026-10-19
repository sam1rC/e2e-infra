-- pool-rls.sql — aislamiento por filas (RLS) para el modelo Pool sobre Aurora/RDS PostgreSQL (SaaS T1). Idempotente.
--
-- Requiere 00-app-runtime.sql. Ejecutar con el usuario maestro o de migraciones:
--   psql "<conexión TLS>" -v ON_ERROR_STOP=1 -f sql/pool-rls.sql
-- Crea app.enable_tenant_rls(tabla, columna), que las migraciones llaman para cada tabla de tenants:
--   SET ROLE app_owner;
--   CREATE TABLE app.orders (tenant_id uuid NOT NULL, id bigint GENERATED ALWAYS AS IDENTITY, ...,
--                            PRIMARY KEY (tenant_id, id));
--   CALL app.enable_tenant_rls('app.orders');
--
-- Contexto de tenant (ADR 0009): la aplicación lo fija DENTRO de cada transacción, nunca en la sesión:
--   BEGIN;
--   SELECT set_config('app.current_tenant', '<uuid del JWT validado>', true);  -- true = local a la transacción
--   ... consultas ...
--   COMMIT;
-- y el pool de conexiones ejecuta RESET ALL al devolver la conexión. Sin contexto, la política compara con
-- NULL y no devuelve ni acepta ninguna fila (falla cerrado); un valor que no sea uuid aborta la transacción.

\set ON_ERROR_STOP on

BEGIN;

SET LOCAL ROLE app_owner;

CREATE OR REPLACE PROCEDURE app.enable_tenant_rls(tbl regclass, tenant_column name DEFAULT 'tenant_id')
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $proc$
BEGIN
  PERFORM 1
  FROM pg_attribute
  WHERE attrelid = tbl AND attname = tenant_column AND atttypid = 'uuid'::regtype
    AND attnotnull AND NOT attisdropped;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'La tabla % necesita la columna % de tipo uuid NOT NULL', tbl, tenant_column;
  END IF;

  EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY', tbl);
  -- FORCE: la política también aplica al dueño (app_owner); las migraciones que muevan datos fijan el contexto.
  EXECUTE format('ALTER TABLE %s FORCE ROW LEVEL SECURITY', tbl);
  EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON %s', tbl);
  EXECUTE format(
    $pol$CREATE POLICY tenant_isolation ON %s
           USING (%I = nullif(current_setting('app.current_tenant', true), '')::uuid)
           WITH CHECK (%I = nullif(current_setting('app.current_tenant', true), '')::uuid)$pol$,
    tbl, tenant_column, tenant_column);
END;
$proc$;

REVOKE ALL ON PROCEDURE app.enable_tenant_rls(regclass, name) FROM PUBLIC;

RESET ROLE;

COMMIT;
