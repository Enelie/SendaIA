-- Bloque 11: eliminacion del cuestionario SCQ (migracion TEA -> TDAH, capa 2).
--
-- El SCQ es un cribado de autismo (TEA); no forma parte de los RF01-RF27 y
-- contradice RF05/RF24 ("el sistema no infiere ni diagnostica"). Su modulo se
-- elimino del backend y de la app. Esta migracion limpia los datos que dejo
-- en ninos.perfil_sensorial->'triaje':
--   * borra requiere_scq, scq_completado, scq (respuestas y puntaje) y
--     fecha_autorizacion_envio;
--   * fija autorizado_envio_terapeuta = true: sin cribado, todo caso
--     registrado llega a la bandeja del terapeuta (misma regla que el
--     backend aplica a los registros nuevos).
-- Los datos SCQ borrados no se pueden recuperar salvo desde un backup.
-- Idempotente: puede aplicarse varias veces.

BEGIN;

UPDATE ninos
SET perfil_sensorial = jsonb_set(
        perfil_sensorial,
        '{triaje}',
        (
            (perfil_sensorial->'triaje')
            - 'requiere_scq'
            - 'scq_completado'
            - 'scq'
            - 'fecha_autorizacion_envio'
        ) || '{"autorizado_envio_terapeuta": true}'::jsonb
    )
WHERE jsonb_typeof(perfil_sensorial->'triaje') = 'object'
  AND (
        perfil_sensorial->'triaje' ?| ARRAY['requiere_scq', 'scq_completado', 'scq', 'fecha_autorizacion_envio']
        OR COALESCE(perfil_sensorial->'triaje'->>'autorizado_envio_terapeuta', 'false') <> 'true'
      );

-- La evidencia de cumplimiento ya no menciona el SCQ.
UPDATE evidencias_cumplimiento
SET descripcion = 'Los modulos de riesgo y recomendaciones declaran uso de apoyo y no diagnostico; el aplicativo no aplica cuestionarios de cribado.',
    updated_at = NOW()
WHERE control = 'advertencia_clinica'
  AND descripcion ILIKE '%SCQ%';

COMMIT;
