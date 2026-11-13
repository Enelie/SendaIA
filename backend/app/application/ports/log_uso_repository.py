from abc import ABC, abstractmethod
from datetime import datetime
from typing import Dict, List

from app.domain.entities.log_uso import EventoUso, FilaUsoParticipante


class ILogUsoRepository(ABC):
    @abstractmethod
    def registrar_eventos(
        self, usuario_id: str, rol_usuario: str, eventos: List[EventoUso]
    ) -> Dict[str, str]:
        """Registra cada evento de forma independiente.

        Devuelve {client_event_id: resultado}, con resultado en
        insertado | duplicado | conflicto | rechazado_bd | error.
        """

    @abstractmethod
    def listar_uso_participantes(
        self, desde: datetime, hasta: datetime, incluir_inactivos: bool
    ) -> List[FilaUsoParticipante]:
        """LEFT JOIN participantes_estudio -> logs_uso con ingreso en [desde, hasta)."""
