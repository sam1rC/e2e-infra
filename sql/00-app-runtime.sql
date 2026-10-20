-- 00-app-runtime.sql — roles base de la aplicación (todos los tiers con PostgreSQL). Idempotente.
--
-- Ejecutar UNA vez por base de datos, con el usuario maestro (secreto gestionado por RDS), por TLS:
--   psql "host=<writer> dbname=<db> user=<maestro> sslmode=verify-full sslrootcert=global-bundle.pem" \
--        -v ON_ERROR_STOP=1 -f sql/00-app-runtime.sql
-- Después: inicializar el secreto app_runtime y rotarlo (ver sql/README.md). Requiere PostgreSQL >= 16.
--
-- Modelo de roles:
--   app_owner    NOLOGIN. Dueño de esquemas y tablas; solo lo usan las migraciones (SET ROLE app_owner).
--   app_runtime  LOGIN sin contraseña. Lo usa la aplicación a través del secreto app_runtime: la rotación
--                multiusuario de Secrets Manager crea app_runtime_clone (GRANT app_runtime TO ..._clone) y
--                alterna contraseñas entre ambos. Ningún privilegio de administración ni BYPASSRLS, y no es
--                dueño de nada, así que las políticas RLS le aplican siempre.
-- Este script no maneja contraseñas: así ninguna acaba en el historial de psql ni en los logs de errores.

\set ON_ERROR_STOP on

BEGIN;

SELECT 'CREATE ROLE app_owner NOLOGIN'
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_owner') \gexec

SELECT 'CREATE ROLE app_runtime LOGIN'
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_runtime') \gexec

-- Fija los atributos aunque los roles ya existieran (repetir el script corrige desviaciones). SUPERUSER,
-- REPLICATION y BYPASSRLS no se pueden nombrar sin ser superusuario (el maestro de RDS no lo es): se
-- comprueban abajo y el script falla si alguno estuviera activo.
ALTER ROLE app_owner NOLOGIN NOCREATEDB NOCREATEROLE;
ALTER ROLE app_runtime LOGIN NOCREATEDB NOCREATEROLE INHERIT;

DO $check$
BEGIN
  IF EXISTS (SELECT FROM pg_roles WHERE rolname IN ('app_owner', 'app_runtime')
             AND (rolsuper OR rolreplication OR rolbypassrls)) THEN
    RAISE EXCEPTION 'app_owner/app_runtime no pueden tener SUPERUSER, REPLICATION ni BYPASSRLS';
  END IF;
END
$check$;

-- El maestro (y el usuario de migraciones) actúa como app_owner con SET ROLE explícito, sin heredar:
-- los objetos que creen las migraciones pertenecen a app_owner, nunca a un usuario con login.
GRANT app_owner TO CURRENT_USER WITH INHERIT FALSE, SET TRUE;

-- Nadie se conecta por defecto; app_runtime sí.
SELECT format('REVOKE ALL ON DATABASE %I FROM PUBLIC', current_database()) \gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO app_runtime', current_database()) \gexec
-- app_owner crea los esquemas (el de la aplicación y los de tenant del modelo Bridge).
SELECT format('GRANT CREATE ON DATABASE %I TO app_owner', current_database()) \gexec

-- Sin objetos en public (por defecto ya es así desde PostgreSQL 15; se fuerza por si la base es antigua).
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- Esquema de la aplicación (Pool y tablas compartidas): app_runtime usa, no crea.
SET LOCAL ROLE app_owner;
CREATE SCHEMA IF NOT EXISTS app;
REVOKE ALL ON SCHEMA app FROM PUBLIC;
GRANT USAGE ON SCHEMA app TO app_runtime;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_runtime;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT USAGE, SELECT ON SEQUENCES TO app_runtime;
-- Para tablas creadas antes de este script.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app TO app_runtime;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO app_runtime;
-- Las funciones nuevas de app_owner no son ejecutables por PUBLIC salvo concesión explícita (los defaults por
-- esquema solo pueden añadir privilegios, así que la revocación tiene que ser global para el rol).
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON ROUTINES FROM PUBLIC;
RESET ROLE;

COMMIT;

-- Comprobación: app_runtime no puede tener atributos de administración ni ser dueño de nada.
SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolbypassrls, rolcanlogin
FROM pg_roles WHERE rolname IN ('app_owner', 'app_runtime') ORDER BY rolname;
