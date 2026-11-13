-- ============================================================
-- Asignacion de codigos de participante (P01, P02, ...)
-- ============================================================
-- Ejecutar UNA vez antes de iniciar la intervencion, despues de la
-- migracion 14_migration_log_uso.sql. Procedimiento completo en
-- docs/06_logs_y_metricas.md.
--
-- Incluye a los usuarios que cumplen TODO lo siguiente:
--   * rol padre_tutor y cuenta activa;
--   * al menos un consentimiento informado aceptado y no revocado;
--   * no pertenecen a las cuentas de prueba (@rimai.dev);
--   * todavia no tienen codigo.
-- Los codigos nuevos se numeran por fecha del primer consentimiento y
-- continuan desde el codigo mas alto ya asignado, de modo que volver a
-- ejecutar el script nunca cambia ni duplica un codigo existente.
--
-- Uso (PowerShell, desde la raiz del repo):
--   docker cp backend\sql\seed_participantes_estudio.sql rimai_postgres:/tmp/seed_participantes_estudio.sql
--   docker exec rimai_postgres psql -U rimai_user -d rimai_db -v ON_ERROR_STOP=1 -f /tmp/seed_participantes_estudio.sql
-- ============================================================

BEGIN;

WITH candidatos AS (
    SELECT
        u.id AS usuario_id,
        (ARRAY_AGG(c.id ORDER BY c.accepted_at, c.id))[1] AS consentimiento_id,
        MIN(c.accepted_at) AS primer_consentimiento
    FROM usuarios u
    JOIN padres_tutores pt ON pt.usuario_id = u.id
    JOIN consentimientos_informados c
      ON (c.usuario_id = u.id OR c.tutor_id = pt.id)
     AND c.aceptado = TRUE
     AND c.revoked_at IS NULL
    WHERE u.rol = 'padre_tutor'
      AND u.activo = TRUE
      AND u.email NOT ILIKE '%@rimai.dev'
      AND NOT EXISTS (
          SELECT 1 FROM participantes_estudio p WHERE p.usuario_id = u.id
      )
    GROUP BY u.id
),
ultimo AS (
    SELECT COALESCE(MAX(SUBSTRING(codigo FROM 2)::int), 0) AS n
    FROM participantes_estudio
),
numerados AS (
    SELECT
        c.usuario_id,
        c.consentimiento_id,
        ultimo.n + ROW_NUMBER() OVER (
            ORDER BY c.primer_consentimiento, c.usuario_id
        ) AS n
    FROM candidatos c
    CROSS JOIN ultimo
)
INSERT INTO participantes_estudio (codigo, usuario_id, consentimiento_id)
SELECT
    'P' || LPAD(n::text, GREATEST(2, LENGTH(n::text)), '0'),
    usuario_id,
    consentimiento_id
FROM numerados
ON CONFLICT (usuario_id) DO NOTHING;

COMMIT;

-- Verificacion: tabla de correspondencia (solo para el investigador;
-- no se exporta ni se publica).
SELECT
    p.codigo,
    u.nombre,
    u.email,
    p.fecha_inclusion,
    p.activo
FROM participantes_estudio p
JOIN usuarios u ON u.id = p.usuario_id
ORDER BY LENGTH(p.codigo), p.codigo;

SELECT COUNT(*) AS total_participantes_activos
FROM participantes_estudio
WHERE activo = TRUE;
