"""Seguimiento familiar: historial de actividades realizadas en casa (solo lectura).

Lee las tablas existentes (sesiones, resultados_actividad, planes_terapeuticos);
no escribe ni modifica el esquema. El registro de actividades sigue usando
POST /api/sesiones.
"""
from datetime import date, timedelta
from typing import Any, Dict, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg2.extras import RealDictCursor

from app.infrastructure.database import get_connection
from .dependencies import get_current_user

router = APIRouter(tags=["seguimiento-familiar"])

ROLES_TUTOR = ("padre_tutor", "tutor", "padre")
MAX_RANGO_DIAS = 366
MAX_REGISTROS = 200

# Solo en los registros de la app familiar `tiempo_respuesta` es la duración
# total cronometrada; en registros legacy es un tiempo de respuesta por intento.
DURACION_SQL = (
    "CASE WHEN s.origen_registro IN ('familia_app', 'familia_app_offline') "
    "THEN ra.tiempo_respuesta END"
)


def _parse_fecha(value: Optional[str], campo: str) -> Optional[date]:
    if not value:
        return None
    try:
        return date.fromisoformat(value)
    except ValueError:
        raise HTTPException(status_code=422, detail=f"'{campo}' debe tener formato YYYY-MM-DD")


def _iso(value: Any) -> Optional[str]:
    return value.isoformat() if value is not None else None


def _nino_del_tutor(cur, nino_id: str, current_user: Dict[str, Any]) -> Dict[str, Any]:
    """Comprueba en BD que el niño pertenece al tutor autenticado."""
    if current_user.get("role") not in ROLES_TUTOR:
        raise HTTPException(status_code=403, detail="Solo los tutores pueden consultar el seguimiento familiar")
    try:
        UUID(nino_id)
    except ValueError:
        raise HTTPException(status_code=404, detail="Niño no encontrado para este tutor")
    cur.execute(
        """
        SELECT n.id, n.nombre
        FROM ninos n
        JOIN padres_tutores t ON t.id = n.tutor_id
        WHERE n.id = %s AND n.activo = TRUE AND t.usuario_id = %s
        """,
        (nino_id, current_user["id"]),
    )
    nino = cur.fetchone()
    if not nino:
        raise HTTPException(status_code=404, detail="Niño no encontrado para este tutor")
    return nino


@router.get("/api/dashboard/familia/ninos/{nino_id}/seguimiento")
def obtener_seguimiento_familiar(
    nino_id: str,
    desde: Optional[str] = Query(None, description="YYYY-MM-DD (inclusive)"),
    hasta: Optional[str] = Query(None, description="YYYY-MM-DD (inclusive)"),
    current_user: dict = Depends(get_current_user),
):
    fecha_hasta = _parse_fecha(hasta, "hasta") or date.today()
    fecha_desde = _parse_fecha(desde, "desde") or (fecha_hasta - timedelta(days=89))
    if fecha_desde > fecha_hasta:
        raise HTTPException(status_code=422, detail="'desde' no puede ser posterior a 'hasta'")
    if (fecha_hasta - fecha_desde).days > MAX_RANGO_DIAS:
        raise HTTPException(status_code=422, detail=f"El rango máximo es de {MAX_RANGO_DIAS} días")

    rango = (fecha_desde, fecha_hasta + timedelta(days=1))

    with get_connection() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            nino = _nino_del_tutor(cur, nino_id, current_user)

            # Actividades efectivamente registradas (una fila por resultado).
            cur.execute(
                f"""
                SELECT
                    ra.id AS registro_id,
                    s.id AS sesion_id,
                    s.plan_id,
                    s.fecha_inicio,
                    s.estado::text AS estado,
                    s.origen_registro,
                    a.id AS actividad_id,
                    a.nombre AS actividad_nombre,
                    a.tipo AS actividad_tipo,
                    a.duracion_estimada,
                    {DURACION_SQL} AS duracion_segundos,
                    ra.aciertos,
                    ra.repeticiones,
                    ra.nivel_ayuda_requerido,
                    ra.nivel_dificultad_usado::text AS nivel_dificultad_usado,
                    NULLIF(TRIM(COALESCE(ra.observaciones, '')), '') AS observaciones
                FROM sesiones s
                JOIN resultados_actividad ra ON ra.sesion_id = s.id
                JOIN actividades a ON a.id = ra.actividad_id
                WHERE s.nino_id = %s
                  AND s.fecha_inicio >= %s
                  AND s.fecha_inicio < %s
                ORDER BY s.fecha_inicio DESC, ra.timestamp DESC
                LIMIT %s
                """,
                (nino_id, *rango, MAX_REGISTROS),
            )
            registros = cur.fetchall()

            # Totales y conteo semanal calculados sobre todo el rango (no
            # dependen del límite de filas del historial).
            cur.execute(
                f"""
                SELECT
                    COUNT(ra.id) AS actividades_completadas,
                    COUNT(DISTINCT date_trunc('day', s.fecha_inicio)) AS dias_con_actividad,
                    SUM({DURACION_SQL}) AS segundos_totales,
                    COUNT({DURACION_SQL}) AS registros_con_duracion,
                    SUM(ra.aciertos) AS aciertos,
                    SUM(ra.repeticiones) AS intentos
                FROM sesiones s
                JOIN resultados_actividad ra ON ra.sesion_id = s.id
                WHERE s.nino_id = %s
                  AND s.estado = 'completada'
                  AND s.fecha_inicio >= %s
                  AND s.fecha_inicio < %s
                """,
                (nino_id, *rango),
            )
            totales = cur.fetchone() or {}

            cur.execute(
                f"""
                SELECT
                    date_trunc('week', s.fecha_inicio)::date AS semana,
                    COUNT(ra.id) AS actividades,
                    SUM({DURACION_SQL}) AS segundos
                FROM sesiones s
                JOIN resultados_actividad ra ON ra.sesion_id = s.id
                WHERE s.nino_id = %s
                  AND s.estado = 'completada'
                  AND s.fecha_inicio >= %s
                  AND s.fecha_inicio < %s
                GROUP BY semana
                ORDER BY semana
                """,
                (nino_id, *rango),
            )
            semanas = cur.fetchall()

            # Actividades recomendadas visibles para la familia (plan publicado).
            cur.execute(
                """
                SELECT
                    pt.id AS plan_id,
                    a.id AS actividad_id,
                    a.nombre,
                    a.tipo,
                    a.duracion_estimada,
                    (
                        SELECT MAX(s.fecha_inicio)
                        FROM sesiones s
                        JOIN resultados_actividad ra ON ra.sesion_id = s.id
                        WHERE s.plan_id = pt.id
                          AND s.nino_id = pt.nino_id
                          AND s.estado = 'completada'
                          AND ra.actividad_id = a.id
                    ) AS ultima_realizacion
                FROM planes_terapeuticos pt
                JOIN plan_actividades pa ON pa.plan_id = pt.id
                JOIN actividades a ON a.id = pa.actividad_id
                WHERE pt.nino_id = %s
                  AND pt.activo = TRUE
                  AND pt.estado_plan = 'publicado'
                  AND pt.publicado_para_tutor = TRUE
                ORDER BY pa.orden
                """,
                (nino_id,),
            )
            recomendadas = cur.fetchall()

    segundos_totales = totales.get("segundos_totales")
    return {
        "nino_id": str(nino["id"]),
        "nino_nombre": nino["nombre"],
        "desde": fecha_desde.isoformat(),
        "hasta": fecha_hasta.isoformat(),
        "resumen": {
            "actividades_completadas": int(totales.get("actividades_completadas") or 0),
            "dias_con_actividad": int(totales.get("dias_con_actividad") or 0),
            "segundos_totales": float(segundos_totales) if segundos_totales is not None else None,
            "registros_con_duracion": int(totales.get("registros_con_duracion") or 0),
            "aciertos": int(totales.get("aciertos") or 0),
            "intentos": int(totales.get("intentos") or 0),
        },
        "por_semana": [
            {
                "semana": s["semana"].isoformat(),
                "actividades": int(s["actividades"] or 0),
                "segundos": float(s["segundos"]) if s["segundos"] is not None else None,
            }
            for s in semanas
        ],
        "registros": [
            {
                "id": str(r["registro_id"]),
                "sesion_id": str(r["sesion_id"]),
                "plan_id": str(r["plan_id"]),
                "fecha": _iso(r["fecha_inicio"]),
                "estado": r["estado"],
                "origen_registro": r["origen_registro"],
                "actividad_id": str(r["actividad_id"]),
                "actividad_nombre": r["actividad_nombre"],
                "actividad_tipo": r["actividad_tipo"],
                "duracion_segundos": float(r["duracion_segundos"]) if r["duracion_segundos"] is not None else None,
                "duracion_estimada_segundos": r["duracion_estimada"],
                "aciertos": r["aciertos"],
                "intentos": r["repeticiones"],
                "nivel_ayuda_requerido": r["nivel_ayuda_requerido"],
                "nivel_dificultad_usado": r["nivel_dificultad_usado"],
                "observaciones": r["observaciones"],
            }
            for r in registros
        ],
        "registros_truncados": len(registros) >= MAX_REGISTROS,
        "recomendadas": [
            {
                "plan_id": str(r["plan_id"]),
                "actividad_id": str(r["actividad_id"]),
                "nombre": r["nombre"],
                "tipo": r["tipo"],
                "duracion_estimada_segundos": r["duracion_estimada"],
                "realizada": r["ultima_realizacion"] is not None,
                "ultima_realizacion": _iso(r["ultima_realizacion"]),
            }
            for r in recomendadas
        ],
    }
