-- ============================================================
-- RimAI — Migración 14: actividades realizadas en casa por la familia
-- ============================================================
-- Permite que el padre/tutor registre una actividad sugerida por la IA
-- sin necesidad de que exista un plan terapeutico publicado.
-- No reemplaza `sesiones`/`resultados_actividad`: esos siguen siendo el
-- registro de las actividades de un plan clinico. Esta tabla guarda las
-- actividades educativas que la familia realiza por su cuenta.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS registros_actividad_familia (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nino_id UUID NOT NULL REFERENCES ninos(id) ON DELETE CASCADE,
    actividad_id UUID NOT NULL REFERENCES actividades(id),
    fecha TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    estado VARCHAR(20) NOT NULL DEFAULT 'completada'
        CHECK (estado IN ('completada', 'interrumpida')),
    modalidad VARCHAR(20) NOT NULL DEFAULT 'casa_sin_app'
        CHECK (modalidad IN ('guiada_app', 'casa_sin_app')),
    duracion_segundos INT
        CHECK (duracion_segundos IS NULL OR duracion_segundos >= 0),
    aciertos INT
        CHECK (aciertos IS NULL OR aciertos >= 0),
    repeticiones INT
        CHECK (repeticiones IS NULL OR repeticiones >= 0),
    nivel_ayuda_requerido INT NOT NULL DEFAULT 0
        CHECK (nivel_ayuda_requerido BETWEEN 0 AND 2),
    observaciones TEXT,
    client_event_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_registros_familia_nino_fecha
    ON registros_actividad_familia (nino_id, fecha DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_registros_familia_client_event
    ON registros_actividad_familia (client_event_id)
    WHERE client_event_id IS NOT NULL;

COMMIT;
