import logging
from datetime import datetime
from typing import Dict, List

import psycopg2
from psycopg2.extras import RealDictCursor

from app.application.ports.log_uso_repository import ILogUsoRepository
from app.domain.entities.log_uso import (
    RESULTADO_ERROR,
    RESULTADO_RECHAZADO_BD,
    EventoUso,
    FilaUsoParticipante,
)
from app.infrastructure.database import get_connection

logger = logging.getLogger(__name__)

# SQLSTATE de validacion: reintentar no cambiaria el resultado.
#   22xxx datos invalidos (incluye 22023 que lanza el SP)
#   23xxx restricciones de integridad (CHECK, FK)
#   P0002 usuario inexistente (lanzado por el SP)
_PGCODES_PERMANENTES_PREFIJOS = ("22", "23")
_PGCODES_PERMANENTES = {"P0002"}


def _es_rechazo_permanente(pgcode) -> bool:
    if not pgcode:
        return False
    return pgcode in _PGCODES_PERMANENTES or pgcode.startswith(_PGCODES_PERMANENTES_PREFIJOS)


class PostgresLogUsoRepository(ILogUsoRepository):
    """Persistencia de logs_uso mediante sp_registrar_log_uso."""

    def registrar_eventos(
        self, usuario_id: str, rol_usuario: str, eventos: List[EventoUso]
    ) -> Dict[str, str]:
        resultados: Dict[str, str] = {}
        if not eventos:
            return resultados

        with get_connection() as conn:
            with conn.cursor() as cur:
                for evento in eventos:
                    event_id = str(evento.client_event_id)
                    # Un SAVEPOINT por evento: un evento invalido no aborta el lote.
                    cur.execute("SAVEPOINT log_uso_evento")
                    try:
                        cur.execute(
                            """
                            CALL sp_registrar_log_uso(
                                %s::uuid, %s::uuid, %s, %s, %s, %s, %s, %s, NULL
                            )
                            """,
                            (
                                event_id,
                                str(usuario_id),
                                rol_usuario,
                                evento.fecha_hora_ingreso,
                                evento.fecha_hora_salida,
                                evento.tipo_cierre,
                                evento.plataforma,
                                evento.version_app,
                            ),
                        )
                        row = cur.fetchone()
                        cur.execute("RELEASE SAVEPOINT log_uso_evento")
                        resultados[event_id] = row[0] if row else RESULTADO_ERROR
                    except psycopg2.Error as exc:
                        cur.execute("ROLLBACK TO SAVEPOINT log_uso_evento")
                        if _es_rechazo_permanente(exc.pgcode):
                            logger.warning(
                                "Evento de uso %s rechazado por la BD (%s)", event_id, exc.pgcode
                            )
                            resultados[event_id] = RESULTADO_RECHAZADO_BD
                        else:
                            logger.exception("Error transitorio registrando evento de uso %s", event_id)
                            resultados[event_id] = RESULTADO_ERROR
        return resultados

    def listar_uso_participantes(
        self, desde: datetime, hasta: datetime, incluir_inactivos: bool
    ) -> List[FilaUsoParticipante]:
        with get_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT
                        p.codigo,
                        p.activo,
                        l.fecha_hora_ingreso,
                        l.fecha_hora_salida,
                        l.tiempo_permanencia_min,
                        l.tipo_cierre
                    FROM participantes_estudio p
                    LEFT JOIN logs_uso l
                      ON l.usuario_id = p.usuario_id
                     AND l.fecha_hora_ingreso >= %s
                     AND l.fecha_hora_ingreso < %s
                    WHERE (%s OR p.activo = TRUE)
                    ORDER BY LENGTH(p.codigo), p.codigo, l.fecha_hora_ingreso
                    """,
                    (desde, hasta, incluir_inactivos),
                )
                rows = cur.fetchall()

        return [
            FilaUsoParticipante(
                codigo=r["codigo"],
                activo=r["activo"],
                fecha_hora_ingreso=r["fecha_hora_ingreso"],
                fecha_hora_salida=r["fecha_hora_salida"],
                tiempo_permanencia_min=(
                    float(r["tiempo_permanencia_min"])
                    if r["tiempo_permanencia_min"] is not None
                    else None
                ),
                tipo_cierre=r["tipo_cierre"],
            )
            for r in rows
        ]
