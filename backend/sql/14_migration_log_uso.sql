-- Bloque 10: registro de uso del aplicativo (Instrumento 3 de la tesis).
--
-- logs_uso alimenta los indicadores de la ficha de registro de uso:
--   FU  = N / S    (accesos por semana)
--   TPP = suma(T) / N   (minutos promedio por acceso)
-- participantes_estudio seudonimiza a los padres (P01, P02, ...) para la
-- exportacion. Ver docs/06_logs_y_metricas.md.
--
-- Es una tabla distinta de logs_auditoria: aquella registra cambios clinicos
-- sobre entidades; esta registra sesiones de uso (ingreso/salida).
-- Idempotente: puede aplicarse varias veces.

BEGIN;

-- ------------------------------------------------------------
-- participantes_estudio: un codigo por padre, ligado a su consentimiento
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS participantes_estudio (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    codigo VARCHAR(10) NOT NULL,
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    consentimiento_id UUID NOT NULL REFERENCES consentimientos_informados(id) ON DELETE RESTRICT,
    fecha_inclusion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- FALSE = retirado del estudio: se excluye del analisis sin borrar datos.
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT participantes_estudio_codigo_key UNIQUE (codigo),
    CONSTRAINT participantes_estudio_usuario_id_key UNIQUE (usuario_id),
    CONSTRAINT participantes_estudio_codigo_formato CHECK (codigo ~ '^P[0-9]{2,3}$')
);

-- ------------------------------------------------------------
-- logs_uso: una fila por acceso (sesion de uso) al aplicativo
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS logs_uso (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- Generado en el dispositivo: hace idempotente la sincronizacion offline.
    client_event_id UUID NOT NULL,
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    rol_usuario VARCHAR(50) NOT NULL,
    fecha_hora_ingreso TIMESTAMPTZ NOT NULL,
    fecha_hora_salida TIMESTAMPTZ NOT NULL,
    -- T se calcula en la base de datos, nunca en el cliente.
    tiempo_permanencia_min NUMERIC(8, 2) GENERATED ALWAYS AS (
        ROUND((EXTRACT(EPOCH FROM (fecha_hora_salida - fecha_hora_ingreso)) / 60.0)::numeric, 2)
    ) STORED,
    tipo_cierre VARCHAR(20) NOT NULL,
    plataforma VARCHAR(20),
    version_app VARCHAR(20),
    fecha_sync TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT logs_uso_client_event_id_key UNIQUE (client_event_id),
    CONSTRAINT logs_uso_salida_posterior CHECK (fecha_hora_salida >= fecha_hora_ingreso),
    CONSTRAINT logs_uso_tipo_cierre_valido
        CHECK (tipo_cierre IN ('logout', 'segundo_plano', 'recuperada'))
);

CREATE INDEX IF NOT EXISTS idx_logs_uso_usuario_ingreso
ON logs_uso (usuario_id, fecha_hora_ingreso);

-- ------------------------------------------------------------
-- sp_registrar_log_uso
-- ------------------------------------------------------------
-- Mismo patron que sp_registrar_auditoria. Devuelve en p_resultado:
--   'insertado'  -> fila nueva
--   'duplicado'  -> el client_event_id ya existia para el mismo usuario
--   'conflicto'  -> el client_event_id ya existia para OTRO usuario
-- Las validaciones repiten las del caso de uso (defensa en profundidad).
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_registrar_log_uso(
    IN p_client_event_id UUID,
    IN p_usuario_id UUID,
    IN p_rol_usuario TEXT,
    IN p_fecha_hora_ingreso TIMESTAMPTZ,
    IN p_fecha_hora_salida TIMESTAMPTZ,
    IN p_tipo_cierre TEXT,
    IN p_plataforma TEXT,
    IN p_version_app TEXT,
    OUT p_resultado TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id UUID;
    v_usuario_existente UUID;
BEGIN
    IF p_client_event_id IS NULL THEN
        RAISE EXCEPTION 'client_event_id es requerido' USING ERRCODE = '22023';
    END IF;

    IF p_usuario_id IS NULL
       OR NOT EXISTS (SELECT 1 FROM usuarios WHERE id = p_usuario_id) THEN
        RAISE EXCEPTION 'Usuario % no existe', p_usuario_id USING ERRCODE = 'P0002';
    END IF;

    IF NULLIF(TRIM(COALESCE(p_rol_usuario, '')), '') IS NULL THEN
        RAISE EXCEPTION 'rol_usuario es requerido' USING ERRCODE = '22023';
    END IF;

    IF p_fecha_hora_ingreso IS NULL OR p_fecha_hora_salida IS NULL THEN
        RAISE EXCEPTION 'fecha_hora_ingreso y fecha_hora_salida son requeridas'
            USING ERRCODE = '22023';
    END IF;

    IF p_fecha_hora_salida < p_fecha_hora_ingreso THEN
        RAISE EXCEPTION 'fecha_hora_salida es anterior a fecha_hora_ingreso'
            USING ERRCODE = '22023';
    END IF;

    -- Tolerancia de 5 min por desfase entre el reloj del celular y el servidor.
    IF p_fecha_hora_ingreso > NOW() + INTERVAL '5 minutes' THEN
        RAISE EXCEPTION 'fecha_hora_ingreso esta en el futuro' USING ERRCODE = '22023';
    END IF;

    IF p_fecha_hora_salida - p_fecha_hora_ingreso > INTERVAL '12 hours' THEN
        RAISE EXCEPTION 'La sesion supera la duracion maxima de 12 horas'
            USING ERRCODE = '22023';
    END IF;

    INSERT INTO logs_uso (
        client_event_id,
        usuario_id,
        rol_usuario,
        fecha_hora_ingreso,
        fecha_hora_salida,
        tipo_cierre,
        plataforma,
        version_app
    )
    VALUES (
        p_client_event_id,
        p_usuario_id,
        p_rol_usuario,
        p_fecha_hora_ingreso,
        p_fecha_hora_salida,
        p_tipo_cierre,
        p_plataforma,
        p_version_app
    )
    ON CONFLICT (client_event_id) DO NOTHING
    RETURNING id INTO v_id;

    IF v_id IS NOT NULL THEN
        p_resultado := 'insertado';
        RETURN;
    END IF;

    SELECT usuario_id INTO v_usuario_existente
    FROM logs_uso
    WHERE client_event_id = p_client_event_id;

    p_resultado := CASE
        WHEN v_usuario_existente = p_usuario_id THEN 'duplicado'
        ELSE 'conflicto'
    END;
END;
$$;

INSERT INTO evidencias_cumplimiento (control, descripcion, estado, referencia)
SELECT
    'seudonimizacion_log_uso',
    'La exportacion de logs_uso identifica a los padres solo por su codigo de participante (P01, P02...) y requiere rol admin.',
    'activo',
    'Bloque 10'
WHERE NOT EXISTS (
    SELECT 1 FROM evidencias_cumplimiento WHERE control = 'seudonimizacion_log_uso'
);

COMMIT;
