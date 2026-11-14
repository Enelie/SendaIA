-- ============================================================
-- SendaIA — Migración 16: reparación de texto con mojibake
-- ============================================================
-- Corrige valores guardados como UTF-8 interpretado como Latin-1
-- (por ejemplo "Su habitaciÃ³n" -> "Su habitación").
-- Las funciones son idempotentes: si el texto ya es válido, no lo cambian.
-- ============================================================

SET client_encoding = 'UTF8';

BEGIN;

CREATE OR REPLACE FUNCTION reparar_mojibake_texto(valor text)
RETURNS text AS $$
BEGIN
    IF valor IS NULL OR valor = '' THEN
        RETURN valor;
    END IF;
    BEGIN
        -- Reinterpreta los bytes Latin-1 como UTF-8. Si no es mojibake,
        -- la conversión falla y se conserva el texto original.
        RETURN convert_from(convert_to(valor, 'LATIN1'), 'UTF8');
    EXCEPTION WHEN others THEN
        RETURN valor;
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION reparar_mojibake_jsonb(valor jsonb)
RETURNS jsonb AS $$
DECLARE
    resultado jsonb;
BEGIN
    IF valor IS NULL THEN
        RETURN NULL;
    END IF;

    CASE jsonb_typeof(valor)
        WHEN 'string' THEN
            RETURN to_jsonb(reparar_mojibake_texto(valor #>> '{}'));
        WHEN 'array' THEN
            SELECT COALESCE(
                jsonb_agg(reparar_mojibake_jsonb(elem) ORDER BY ord),
                '[]'::jsonb
            )
            INTO resultado
            FROM jsonb_array_elements(valor) WITH ORDINALITY AS t(elem, ord);
            RETURN resultado;
        WHEN 'object' THEN
            SELECT COALESCE(
                jsonb_object_agg(key, reparar_mojibake_jsonb(item)),
                '{}'::jsonb
            )
            INTO resultado
            FROM jsonb_each(valor) AS t(key, item);
            RETURN resultado;
        ELSE
            RETURN valor;
    END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

UPDATE ninos
SET perfil_sensorial = reparar_mojibake_jsonb(perfil_sensorial),
    nombre = reparar_mojibake_texto(nombre),
    diagnostico = reparar_mojibake_texto(diagnostico)
WHERE perfil_sensorial::text ~ '[ÃÂ]'
   OR nombre ~ '[ÃÂ]'
   OR COALESCE(diagnostico, '') ~ '[ÃÂ]';

COMMIT;
