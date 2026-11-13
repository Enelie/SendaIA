"""Registro de uso del aplicativo (Instrumento 3 de la tesis).

POST /api/v1/logs/uso/sync  -> el dispositivo sube sesiones cerradas (padre_tutor)
GET  /api/v1/logs/export    -> el investigador exporta FU/TPP seudonimizados (admin)
"""
import csv
import io
import json
import logging
from datetime import date, datetime, timezone
from typing import List, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from pydantic import BaseModel, Field

from app.application.ports.auditoria_repository import IAuditoriaRepository
from app.application.usecases.exportar_log_uso_usecase import (
    SEMANAS_MAXIMAS,
    SEMANAS_POR_DEFECTO,
    ExportacionUso,
    ExportarLogUsoUseCase,
)
from app.application.usecases.sincronizar_log_uso_usecase import (
    MAX_EVENTOS_POR_LOTE,
    ROLES_REGISTRABLES,
    SincronizarLogUsoUseCase,
)
from app.domain.entities.log_trazabilidad import LogTrazabilidad
from app.domain.entities.log_uso import EventoUso
from app.infrastructure.rate_limit import limiter

from .dependencies import (
    get_auditoria_repository,
    get_current_user,
    get_exportar_log_uso_usecase,
    get_sincronizar_log_uso_usecase,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/logs", tags=["logs-uso"])


class SyncUsoRequest(BaseModel):
    eventos: List[EventoUso] = Field(default_factory=list, max_length=MAX_EVENTOS_POR_LOTE)


@router.post("/uso/sync")
def sincronizar_uso(
    request: SyncUsoRequest,
    current_user: dict = Depends(get_current_user),
    uc: SincronizarLogUsoUseCase = Depends(get_sincronizar_log_uso_usecase),
):
    if current_user.get("role") not in ROLES_REGISTRABLES:
        raise HTTPException(
            status_code=403, detail="Solo se registran sesiones de uso de padres o tutores"
        )
    try:
        # usuario_id siempre del JWT, nunca del cuerpo.
        resultado = uc.execute(current_user["id"], current_user["role"], request.eventos)
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    return {
        "aceptados": resultado.aceptados,
        "rechazados": resultado.rechazados,
        "reintentar": resultado.reintentar,
    }


def _valor_csv(valor):
    if valor is None:
        return ""
    if isinstance(valor, bool):
        return 1 if valor else 0
    return valor


def _a_csv(exportacion: ExportacionUso) -> bytes:
    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=exportacion.columnas, lineterminator="\r\n")
    writer.writeheader()
    for fila in exportacion.filas:
        writer.writerow({k: _valor_csv(fila.get(k)) for k in exportacion.columnas})
    # BOM para que Excel/SPSS detecten UTF-8.
    return ("﻿" + buffer.getvalue()).encode("utf-8")


@router.get("/export")
@limiter.limit("10/minute")
def exportar_uso(
    request: Request,
    fecha_inicio: date = Query(..., description="Primer dia de la intervencion (hora de Lima)"),
    semanas: int = Query(SEMANAS_POR_DEFECTO, ge=1, le=SEMANAS_MAXIMAS, description="S"),
    nivel: Literal["resumen", "detalle"] = Query("resumen"),
    formato: Literal["csv", "json"] = Query("csv"),
    incluir_inactivos: bool = Query(
        False, description="Incluir participantes retirados (activo = FALSE)"
    ),
    current_user: dict = Depends(get_current_user),
    uc: ExportarLogUsoUseCase = Depends(get_exportar_log_uso_usecase),
    auditoria: IAuditoriaRepository = Depends(get_auditoria_repository),
):
    if current_user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Solo el investigador (admin) puede exportar logs de uso")

    try:
        exportacion = uc.execute(fecha_inicio, semanas, nivel, incluir_inactivos)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    parametros = {
        "fecha_inicio": fecha_inicio.isoformat(),
        "semanas": semanas,
        "nivel": nivel,
        "formato": formato,
        "incluir_inactivos": incluir_inactivos,
    }
    # Si la auditoria falla, la exportacion no se entrega (trazabilidad obligatoria).
    auditoria.log_action(
        LogTrazabilidad(
            usuario_id=current_user["id"],
            rol_usuario="admin",
            accion="EXPORT_LOG_USO",
            entidad_afectada="logs_uso",
            entidad_id=f"{fecha_inicio.isoformat()}/{semanas}s/{nivel}",
            payload_nuevo=json.dumps(
                {
                    **parametros,
                    "participantes": exportacion.metadatos.get("participantes"),
                    "filas": len(exportacion.filas),
                }
            ),
            timestamp_servidor=datetime.now(timezone.utc),
        )
    )

    headers = {"Cache-Control": "no-store"}
    if formato == "json":
        return Response(
            content=json.dumps(
                {
                    "metadatos": exportacion.metadatos,
                    "columnas": exportacion.columnas,
                    "filas": exportacion.filas,
                },
                ensure_ascii=False,
            ),
            media_type="application/json",
            headers=headers,
        )

    nombre = f"log_uso_{nivel}_{fecha_inicio.isoformat()}_{semanas}s.csv"
    headers["Content-Disposition"] = f'attachment; filename="{nombre}"'
    return Response(content=_a_csv(exportacion), media_type="text/csv; charset=utf-8", headers=headers)
