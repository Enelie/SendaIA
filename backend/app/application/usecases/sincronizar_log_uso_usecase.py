"""Recepcion de sesiones de uso registradas offline en el dispositivo."""
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Callable, Dict, List, Optional

from app.application.ports.log_uso_repository import ILogUsoRepository
from app.domain.entities.log_uso import (
    RESULTADO_CONFLICTO,
    RESULTADO_DUPLICADO,
    RESULTADO_INSERTADO,
    RESULTADO_RECHAZADO_BD,
    EventoUso,
)

MAX_EVENTOS_POR_LOTE = 200
# Desfase tolerado entre el reloj del celular y el del servidor.
TOLERANCIA_RELOJ = timedelta(minutes=5)
DURACION_MAXIMA_SESION = timedelta(hours=12)

ROLES_REGISTRABLES = ("padre_tutor", "tutor")


@dataclass
class ResultadoSincronizacionUso:
    # Registrados o ya existentes: el cliente debe borrarlos de su cola.
    aceptados: List[str] = field(default_factory=list)
    # Invalidos de forma permanente: el cliente los marca y no los reintenta.
    rechazados: List[Dict[str, str]] = field(default_factory=list)
    # Fallo transitorio del servidor: el cliente los reintenta.
    reintentar: List[str] = field(default_factory=list)


class SincronizarLogUsoUseCase:
    def __init__(
        self,
        repo: ILogUsoRepository,
        ahora: Callable[[], datetime] = lambda: datetime.now(timezone.utc),
    ):
        self.repo = repo
        self._ahora = ahora

    def _motivo_rechazo(self, evento: EventoUso, ahora: datetime) -> Optional[str]:
        ingreso = evento.fecha_hora_ingreso
        salida = evento.fecha_hora_salida
        if ingreso.tzinfo is None or salida.tzinfo is None:
            return "fecha_sin_zona_horaria"
        if salida < ingreso:
            return "salida_anterior_a_ingreso"
        if ingreso > ahora + TOLERANCIA_RELOJ:
            return "ingreso_en_el_futuro"
        if salida - ingreso > DURACION_MAXIMA_SESION:
            return "duracion_excede_12h"
        return None

    def execute(
        self, usuario_id: str, rol_usuario: str, eventos: List[EventoUso]
    ) -> ResultadoSincronizacionUso:
        if rol_usuario not in ROLES_REGISTRABLES:
            raise PermissionError("Solo se registran sesiones de uso de padres o tutores")
        if len(eventos) > MAX_EVENTOS_POR_LOTE:
            raise ValueError(f"El lote supera el maximo de {MAX_EVENTOS_POR_LOTE} eventos")

        resultado = ResultadoSincronizacionUso()
        ahora = self._ahora()
        validos: List[EventoUso] = []
        vistos = set()

        for evento in eventos:
            event_id = str(evento.client_event_id)
            if event_id in vistos:
                # Repetido dentro del mismo lote: se procesa una sola vez.
                continue
            vistos.add(event_id)

            motivo = self._motivo_rechazo(evento, ahora)
            if motivo:
                resultado.rechazados.append({"client_event_id": event_id, "motivo": motivo})
            else:
                validos.append(evento)

        registro = (
            self.repo.registrar_eventos(str(usuario_id), "padre_tutor", validos)
            if validos
            else {}
        )

        for evento in validos:
            event_id = str(evento.client_event_id)
            estado = registro.get(event_id)
            if estado in (RESULTADO_INSERTADO, RESULTADO_DUPLICADO):
                resultado.aceptados.append(event_id)
            elif estado == RESULTADO_CONFLICTO:
                resultado.rechazados.append(
                    {"client_event_id": event_id, "motivo": "client_event_id_de_otro_usuario"}
                )
            elif estado == RESULTADO_RECHAZADO_BD:
                resultado.rechazados.append(
                    {"client_event_id": event_id, "motivo": "rechazado_por_validacion_bd"}
                )
            else:
                resultado.reintentar.append(event_id)

        return resultado
