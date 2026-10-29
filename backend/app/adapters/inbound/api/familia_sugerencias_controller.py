"""Sugerencias personalizadas de actividades para el panel del padre/tutor."""
from __future__ import annotations

from typing import Any, Dict

from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg2.extras import RealDictCursor

from app.ai.sugerencias_familia import construir_sugerencias
from app.infrastructure.authorization import autorizar_acceso_nino
from app.infrastructure.database import get_connection
from .dependencies import get_current_user

router = APIRouter(prefix="/api/familia", tags=["familia"])

ROLES_TUTOR = ("padre_tutor", "tutor", "padre")


@router.get("/ninos/{nino_id}/sugerencias")
def obtener_sugerencias(
    nino_id: str,
    limite: int = Query(default=3, ge=1, le=5),
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Sugerencias de actividades a partir del perfil educativo del nino.

    Solo el tutor propio del nino. No guarda nada: la seleccion se
    recalcula en cada peticion a partir del catalogo existente.
    """
    if current_user.get("role") not in ROLES_TUTOR:
        raise HTTPException(status_code=403, detail="Acceso denegado")

    autorizar_acceso_nino(nino_id, current_user)

    with get_connection() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT id, nombre, fecha_nacimiento, nivel_cognitivo,
                       perfil_sensorial, objetivos_intervencion
                FROM ninos
                WHERE id = %s AND activo = TRUE
                """,
                (nino_id,),
            )
            nino = cur.fetchone()
            if not nino:
                raise HTTPException(status_code=404, detail="Nino no encontrado")

            cur.execute(
                """
                SELECT id, tipo, nombre, instrucciones, nivel_dificultad,
                       duracion_estimada, recursos_multimedia, activo
                FROM actividades
                WHERE activo = TRUE
                ORDER BY nombre
                """
            )
            catalogo = cur.fetchall()

    return construir_sugerencias(dict(nino), [dict(a) for a in catalogo], limite)
