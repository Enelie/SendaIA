-- Bloque 12: nivel TEA -> nivel de acompanamiento (migracion TEA -> TDAH, capa 3).
--
-- ninos.nivel_tea_validado (1-3) se renombra a ninos.nivel_acompanamiento.
-- Conserva los valores y el flujo de publicacion del plan, pero cambia su
-- significado: ya no es un nivel de severidad TEA, sino cuanto acompanamiento
-- del padre o tutor necesitan las actividades:
--   1 = autonoma con supervision cercana
--   2 = acompanada
--   3 = acompanamiento continuo
-- El backend lo sugiere a partir de los datos de RF07 (atencion, seguimiento
-- de instrucciones, forma de aprendizaje y dificultades) y el terapeuta lo
-- valida; el sistema no lo infiere del diagnostico (RF05/RF24).
--
-- Los registros historicos de decisiones_clinicas y logs_auditoria con
-- 'validacion_nivel_tea' / 'NIVEL_TEA_VALIDADO' no se reescriben: son pista
-- de auditoria. Los registros nuevos usan los nombres de acompanamiento.
-- Idempotente: puede aplicarse varias veces.

BEGIN;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'ninos'
          AND column_name = 'nivel_tea_validado'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'ninos'
          AND column_name = 'nivel_acompanamiento'
    ) THEN
        ALTER TABLE ninos RENAME COLUMN nivel_tea_validado TO nivel_acompanamiento;
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_ninos_nivel_tea_validado'
    ) THEN
        ALTER TABLE ninos
            RENAME CONSTRAINT chk_ninos_nivel_tea_validado TO chk_ninos_nivel_acompanamiento;
    END IF;
END $$;

ALTER INDEX IF EXISTS idx_ninos_nivel_tea_validado RENAME TO idx_ninos_nivel_acompanamiento;

COMMENT ON COLUMN ninos.nivel_acompanamiento IS
    'Nivel de acompanamiento del tutor (1 autonoma con supervision, 2 acompanada, 3 acompanamiento continuo). Sugerido desde RF07 y validado por el terapeuta; no es un diagnostico.';

COMMIT;
