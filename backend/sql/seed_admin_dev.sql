-- ============================================================
-- SENDAIA — Admin de prueba (SOLO DESARROLLO)
-- ============================================================
-- Crea el usuario admin@rimai.dev / Rimai2024! para usar en desarrollo
-- la exportacion del Instrumento 3 (GET /api/v1/logs/export).
--
-- NO ejecutar en produccion: la contrasena es publica (esta en este
-- archivo). No se monta en docker-entrypoint-initdb.d ni figura en
-- apply_migrations.ps1; se ejecuta a mano.
--
-- Salvaguarda: el script se detiene si no se pasa -v confirmar_dev=si.
-- Idempotente: si el correo ya existe no lo duplica ni cambia su
-- contrasena; solo se asegura de que tenga rol admin y este activo.
-- El dominio @rimai.dev queda excluido de seed_participantes_estudio.sql,
-- asi que este usuario nunca recibe codigo de participante.
--
-- Uso (PowerShell, desde la raiz del repo):
--   docker cp backend\sql\seed_admin_dev.sql rimai_postgres:/tmp/seed_admin_dev.sql
--   docker exec rimai_postgres psql -U rimai_user -d rimai_db -v ON_ERROR_STOP=1 -v confirmar_dev=si -f /tmp/seed_admin_dev.sql
-- ============================================================

\if :{?confirmar_dev}
SELECT (:'confirmar_dev' = 'si') AS confirmado \gset
\else
\set confirmado false
\endif
\if :confirmado
\else
\echo 'Detenido: este script es solo para desarrollo. Ejecutalo con -v confirmar_dev=si'
\quit
\endif

BEGIN;

INSERT INTO usuarios (nombre, email, password_hash, rol, activo)
VALUES (
    'Admin de desarrollo',
    'admin@rimai.dev',
    '$2b$12$0uGeTMk5Y6qiAOmRh0HJ0uIuTsvXhMmCnHWSA3frpHxJx4b6CRZEW',   -- Rimai2024! (mismo hash que 05_seed_test.sql)
    'admin',
    TRUE
)
ON CONFLICT (email) DO UPDATE
SET rol = 'admin',
    activo = TRUE,
    updated_at = NOW()
WHERE usuarios.rol IS DISTINCT FROM 'admin' OR usuarios.activo IS DISTINCT FROM TRUE;

SELECT email, rol, activo FROM usuarios WHERE email = 'admin@rimai.dev';

COMMIT;
