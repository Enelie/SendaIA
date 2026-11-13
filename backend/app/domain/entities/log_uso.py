"""Registro de uso del aplicativo (Instrumento 3: FU y TPP).

Ver docs/06_logs_y_metricas.md para las definiciones operativas.
"""
from datetime import datetime
from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

TipoCierre = Literal["logout", "segundo_plano", "recuperada"]

# Resultados que devuelve sp_registrar_log_uso.
RESULTADO_INSERTADO = "insertado"
RESULTADO_DUPLICADO = "duplicado"
RESULTADO_CONFLICTO = "conflicto"
# El SP rechazo el evento por validacion (no tiene sentido reintentar).
RESULTADO_RECHAZADO_BD = "rechazado_bd"
# Error transitorio: el cliente debe reintentar.
RESULTADO_ERROR = "error"


class EventoUso(BaseModel):
    """Una sesion de uso cerrada, tal como la envia el dispositivo.

    No incluye usuario_id: el servidor lo toma del JWT. Campos extra que
    envie el cliente (p. ej. un usuario_id) se ignoran.
    """

    model_config = ConfigDict(extra="ignore")

    client_event_id: UUID
    fecha_hora_ingreso: datetime
    fecha_hora_salida: datetime
    tipo_cierre: TipoCierre
    plataforma: Optional[str] = Field(default=None, max_length=20)
    version_app: Optional[str] = Field(default=None, max_length=20)


class FilaUsoParticipante(BaseModel):
    """Fila del LEFT JOIN participantes_estudio -> logs_uso.

    Un participante sin sesiones en la ventana aparece una vez con los
    campos de sesion en None (asi N = 0 entra en el analisis).
    """

    codigo: str
    activo: bool
    fecha_hora_ingreso: Optional[datetime] = None
    fecha_hora_salida: Optional[datetime] = None
    tiempo_permanencia_min: Optional[float] = None
    tipo_cierre: Optional[str] = None
