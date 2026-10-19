-- bridge-schema-per-tenant.sql — un esquema y un rol por tenant (modelo Bridge, SaaS T2). Idempotente.
--
-- Requiere 00-app-runtime.sql. Ejecutar en el onboarding de cada tenant, con el usuario maestro, por TLS:
--   psql "<conexión TLS>" -v ON_ERROR_STOP=1 -v tenant_id=acme_corp -f sql/bridge-schema-per-tenant.sql
-- y repetirlo tras cada migración que cree tablas nuevas en los esquemas de tenant (concede las existentes).
--
-- Crea el rol tenant_<id> (NOLOGIN) y el esquema tenant_<id> (dueño app_owner, igual que sus tablas). app_runtime puede hacer
-- SET LOCAL ROLE tenant_<id> pero NO hereda sus privilegios (INHERIT FALSE): sin fijar el rol dentro de la
-- transacción no ve ningún esquema de tenant (permission denied), y al terminar la transacción el rol vuelve
-- a app_runtime aunque la conexión siga en el pool (ADR 0009):
--   BEGIN;
--   SET LOCAL ROLE tenant_<id>;   -- el id sale del JWT validado, nunca de la petición
--   SET LOCAL search_path = tenant_<id>;
--   ... consultas ...
--   COMMIT;

\set ON_ERROR_STOP on

\if :{?tenant_id}
\else
  \echo 'Falta -v tenant_id=<id> (minúsculas, dígitos y _, hasta 40 caracteres).'
  \quit
\endif

BEGIN;

-- Las variables de psql no se sustituyen dentro de DO: se pasan por un parámetro de configuración local.
SELECT set_config('bootstrap.tenant_id', :'tenant_id', true);

DO $bridge$
DECLARE
  t text := current_setting('bootstrap.tenant_id');
  r text;
BEGIN
  IF t !~ '^[a-z0-9_]{1,40}$' THEN
    RAISE EXCEPTION 'tenant_id inválido: "%" (solo minúsculas, dígitos y _, 1-40 caracteres)', t;
  END IF;
  r := 'tenant_' || t;

  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = r) THEN
    EXECUTE format('CREATE ROLE %I NOLOGIN NOINHERIT', r);
  END IF;
  EXECUTE format('ALTER ROLE %I NOLOGIN NOCREATEDB NOCREATEROLE', r);
  IF EXISTS (SELECT FROM pg_roles WHERE rolname = r AND (rolsuper OR rolreplication OR rolbypassrls)) THEN
    RAISE EXCEPTION 'El rol % no puede tener SUPERUSER, REPLICATION ni BYPASSRLS', r;
  END IF;

  -- Esquema y privilegios como app_owner (dueño de las tablas); el rol y su concesión, como el maestro.
  EXECUTE 'SET LOCAL ROLE app_owner';
  EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', r);
  EXECUTE format('REVOKE ALL ON SCHEMA %I FROM PUBLIC', r);
  EXECUTE format('GRANT USAGE ON SCHEMA %I TO %I', r, r);

  EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO %I', r, r);
  EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT USAGE, SELECT ON SEQUENCES TO %I', r, r);
  EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA %I TO %I', r, r);
  EXECUTE format('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA %I TO %I', r, r);
  EXECUTE 'RESET ROLE';

  -- SET sí, herencia no: los privilegios del tenant solo existen tras SET LOCAL ROLE.
  EXECUTE format('GRANT %I TO app_runtime WITH INHERIT FALSE, SET TRUE', r);
END
$bridge$;

COMMIT;
