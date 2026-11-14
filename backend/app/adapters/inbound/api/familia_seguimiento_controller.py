"""Seguimiento familiar: historial de actividades realizadas en casa.

Lee `sesiones`/`resultados_actividad` (actividades de un plan clinico) y
`registros_actividad_familia` (actividades sugeridas que la familia realiza
por su cuenta, sin plan publicado). El GET mezcla ambas fuentes; el POST
registra una actividad familiar sin depender de un plan del terapeuta.
"""
from datetime import date, datetime, timedelta
from typing import Any, Dict, Literal, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg2.extras import RealDictCursor
from pydantic import BaseModel, Field

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


class ActividadRealizadaRequest(BaseModel):
    """Registro de una actividad sugerida realizada por la familia."""

    actividad_id: str
    modalidad: Literal["guiada_app", "casa_sin_app"] = "casa_sin_app"
    estado: Literal["completada", "interrumpida"] = "completada"
    duracion_segundos: Optional[int] = Field(default=None, ge=0, le=86400)
    aciertos: Optional[int] = Field(default=None, ge=0, le=100000)
    repeticiones: Optional[int] = Field(default=None, ge=0, le=100000)
    nivel_ayuda_requerido: int = Field(default=0, ge=0, le=2)
    observaciones: Optional[str] = Field(default=None, max_length=1000)
    client_event_id: Optional[str] = None


def _parse_fecha(value: Optional[str], campo: str) -> Optional[date]:
    if not value:
        return None
    try:
        return date.fromisoformat(value)
    except ValueError:
        raise HTTPException(status_code=422, detail=f"'{campo}' debe tener formato YYYY-MM-DD")


def _iso(value: Any) -> Optional[str]:
    return value.isoformat() if value is not None else None


def _str_or_none(value: Any) -> Optional[str]:
    return str(value) if value is not None else None


def _uuid(value: str, campo: str) -> str:
    try:
        return str(UUID(value))
    except (ValueError, TypeError, AttributeError):
        raise HTTPException(status_code=422, detail=f"'{campo}' debe ser un UUID valido")


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

            # Actividades efectivamente registradas: plan clínico + familia.
            cur.execute(
                f"""
                SELECT
                    t.registro_id,
                    t.sesion_id,
                    t.plan_id,
                    t.fecha_inicio,
                    t.estado,
                    t.origen_registro,
                    t.modalidad,
                    t.actividad_id,
                    t.actividad_nombre,
                    t.actividad_tipo,
                    t.duracion_estimada,
                    t.duracion_segundos,
                    t.aciertos,
                    t.repeticiones,
                    t.nivel_ayuda_requerido,
                    t.nivel_dificultad_usado,
                    t.observaciones
                FROM (
                    SELECT
                        ra.id AS registro_id,
                        s.id AS sesion_id,
                        s.plan_id,
                        s.fecha_inicio,
                        s.estado::text AS estado,
                        s.origen_registro,
                        NULL::text AS modalidad,
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
                    UNION ALL
                    SELECT
                        rf.id AS registro_id,
                        NULL::uuid AS sesion_id,
                        NULL::uuid AS plan_id,
                        rf.fecha AS fecha_inicio,
                        rf.estado,
                        CASE rf.modalidad
                            WHEN 'guiada_app' THEN 'familia_app'
                            ELSE 'familia_sin_app'
                        END AS origen_registro,
                        rf.modalidad,
                        a.id AS actividad_id,
                        a.nombre AS actividad_nombre,
                        a.tipo AS actividad_tipo,
                        a.duracion_estimada,
                        rf.duracion_segundos,
                        rf.aciertos,
                        rf.repeticiones,
                        rf.nivel_ayuda_requerido,
                        NULL::text AS nivel_dificultad_usado,
                        NULLIF(TRIM(COALESCE(rf.observaciones, '')), '') AS observaciones
                    FROM registros_actividad_familia rf
                    JOIN actividades a ON a.id = rf.actividad_id
                    WHERE rf.nino_id = %s
                      AND rf.fecha >= %s
                      AND rf.fecha < %s
                ) t
                ORDER BY t.fecha_inicio DESC, t.registro_id DESC
                LIMIT %s
                """,
                (nino_id, *rango, nino_id, *rango, MAX_REGISTROS),
            )
            registros = cur.fetchall()

            # Totales y conteo semanal sobre todo el rango (no dependen del
            # límite de filas del historial), sumando ambas fuentes.
            cur.execute(
                f"""
                SELECT
                    COUNT(*) AS actividades_completadas,
                    COUNT(DISTINCT date_trunc('day', t.fecha_inicio)) AS dias_con_actividad,
                    SUM(t.duracion_segundos) AS segundos_totales,
                    COUNT(t.duracion_segundos) AS registros_con_duracion,
                    SUM(t.aciertos) AS aciertos,
                    SUM(t.repeticiones) AS intentos
                FROM (
                    SELECT
                        s.fecha_inicio,
                        {DURACION_SQL} AS duracion_segundos,
                        ra.aciertos,
                        ra.repeticiones
                    FROM sesiones s
                    JOIN resultados_actividad ra ON ra.sesion_id = s.id
                    WHERE s.nino_id = %s
                      AND s.estado = 'completada'
                      AND s.fecha_inicio >= %s
                      AND s.fecha_inicio < %s
                    UNION ALL
                    SELECT
                        rf.fecha AS fecha_inicio,
                        rf.duracion_segundos,
                        rf.aciertos,
                        rf.repeticiones
                    FROM registros_actividad_familia rf
                    WHERE rf.nino_id = %s
                      AND rf.estado = 'completada'
                      AND rf.fecha >= %s
                      AND rf.fecha < %s
                ) t
                """,
                (nino_id, *rango, nino_id, *rango),
            )
            totales = cur.fetchone() or {}

            cur.execute(
                f"""
                SELECT
                    date_trunc('week', t.fecha_inicio)::date AS semana,
                    COUNT(*) AS actividades,
                    SUM(t.duracion_segundos) AS segundos
                FROM (
                    SELECT
                        s.fecha_inicio,
                        {DURACION_SQL} AS duracion_segundos
                    FROM sesiones s
                    JOIN resultados_actividad ra ON ra.sesion_id = s.id
                    WHERE s.nino_id = %s
                      AND s.estado = 'completada'
                      AND s.fecha_inicio >= %s
                      AND s.fecha_inicio < %s
                    UNION ALL
                    SELECT
                        rf.fecha AS fecha_inicio,
                        rf.duracion_segundos
                    FROM registros_actividad_familia rf
                    WHERE rf.nino_id = %s
                      AND rf.estado = 'completada'
                      AND rf.fecha >= %s
                      AND rf.fecha < %s
                ) t
                GROUP BY semana
                ORDER BY semana
                """,
                (nino_id, *rango, nino_id, *rango),
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
                "sesion_id": _str_or_none(r["sesion_id"]),
                "plan_id": _str_or_none(r["plan_id"]),
                "fecha": _iso(r["fecha_inicio"]),
                "estado": r["estado"],
                "origen_registro": r["origen_registro"],
                "modalidad": r.get("modalidad"),
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


@router.post("/api/familia/ninos/{nino_id}/actividades-realizadas")
def registrar_actividad_familiar(
    nino_id: str,
    payload: ActividadRealizadaRequest,
    current_user: dict = Depends(get_current_user),
):
    """Registra una actividad sugerida realizada en casa, sin plan clínico.

    `client_event_id` hace el registro idempotente: reintentar con el mismo
    valor no duplica la actividad (útil si la app perdió la respuesta).
    """
    actividad_id = _uuid(payload.actividad_id, "actividad_id")
    client_event_id = (
        _uuid(payload.client_event_id, "client_event_id")
        if payload.client_event_id
        else None
    )

    with get_connection() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            _nino_del_tutor(cur, nino_id, current_user)

            if client_event_id:
                cur.execute(
                    """
                    SELECT id, fecha
                    FROM registros_actividad_familia
                    WHERE client_event_id = %s AND nino_id = %s
                    """,
                    (client_event_id, nino_id),
                )
                existente = cur.fetchone()
                if existente:
                    return {
                        "ok": True,
                        "duplicado": True,
                        "registro_id": str(existente["id"]),
                        "fecha": _iso(existente["fecha"]),
                    }

            cur.execute(
                "SELECT id FROM actividades WHERE id = %s AND activo = TRUE",
                (actividad_id,),
            )
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="Actividad no encontrada")

            cur.execute(
                """
                INSERT INTO registros_actividad_familia (
                    nino_id, actividad_id, fecha, estado, modalidad,
                    duracion_segundos, aciertos, repeticiones,
                    nivel_ayuda_requerido, observaciones, client_event_id
                )
                VALUES (%s, %s, NOW(), %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id, fecha
                """,
                (
                    nino_id,
                    actividad_id,
                    payload.estado,
                    payload.modalidad,
                    payload.duracion_segundos,
                    payload.aciertos,
                    payload.repeticiones,
                    payload.nivel_ayuda_requerido,
                    (payload.observaciones or "").strip() or None,
                    client_event_id,
                ),
            )
            creado = cur.fetchone()

    return {
        "ok": True,
        "duplicado": False,
        "registro_id": str(creado["id"]),
        "fecha": _iso(creado["fecha"]),
    }
