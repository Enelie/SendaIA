"""Exportacion de la ficha de registro de uso (Instrumento 3).

Definiciones (docs/06_logs_y_metricas.md):
  N   = accesos del participante con ingreso dentro de la intervencion
  S   = semanas de intervencion (parametro, 8 por defecto)
  FU  = N / S
  T   = fecha_hora_salida - fecha_hora_ingreso, en minutos (calculado en BD)
  ΣT  = suma de T del participante
  TPP = ΣT / N   (None si N = 0)
"""
from dataclasses import dataclass, field
from datetime import date, datetime, time, timedelta, timezone, tzinfo
from decimal import ROUND_HALF_UP, Decimal
from typing import Any, Dict, List, Literal, Optional, Tuple

from app.application.ports.log_uso_repository import ILogUsoRepository
from app.domain.entities.log_uso import FilaUsoParticipante

NivelExportacion = Literal["resumen", "detalle"]

SEMANAS_POR_DEFECTO = 8
SEMANAS_MAXIMAS = 52
DECIMALES = 2


def _zona_lima() -> tzinfo:
    """America/Lima; si el sistema no trae la base IANA (p. ej. Windows sin
    tzdata), UTC-5 fijo, que es equivalente porque Peru no aplica horario de
    verano desde 1994."""
    try:
        from zoneinfo import ZoneInfo

        return ZoneInfo("America/Lima")
    except Exception:  # ZoneInfoNotFoundError o modulo ausente
        return timezone(timedelta(hours=-5), "America/Lima")


ZONA_LIMA = _zona_lima()


@dataclass
class ExportacionUso:
    columnas: List[str]
    filas: List[Dict[str, Any]]
    metadatos: Dict[str, Any] = field(default_factory=dict)


def ventana_intervencion(fecha_inicio: date, semanas: int) -> Tuple[datetime, datetime]:
    """[inicio, fin) en hora de Lima: fin = inicio + 7*S dias."""
    desde = datetime.combine(fecha_inicio, time.min, tzinfo=ZONA_LIMA)
    hasta = datetime.combine(fecha_inicio + timedelta(days=7 * semanas), time.min, tzinfo=ZONA_LIMA)
    return desde, hasta


def semana_de(ingreso: datetime, fecha_inicio: date) -> int:
    """Semana 1..S segun la fecha calendario de Lima."""
    dias = (ingreso.astimezone(ZONA_LIMA).date() - fecha_inicio).days
    return dias // 7 + 1


def _redondear(valor: Optional[float]) -> Optional[float]:
    """Redondeo convencional (medio hacia arriba), no el bancario de round():
    0.125 -> 0.13, igual que un calculo manual o en Excel."""
    if valor is None:
        return None
    cuantizado = Decimal(str(valor)).quantize(Decimal(1).scaleb(-DECIMALES), rounding=ROUND_HALF_UP)
    return float(cuantizado)


def _iso_lima(valor: Optional[datetime]) -> Optional[str]:
    return valor.astimezone(ZONA_LIMA).isoformat() if valor else None


class ExportarLogUsoUseCase:
    def __init__(self, repo: ILogUsoRepository):
        self.repo = repo

    def execute(
        self,
        fecha_inicio: date,
        semanas: int = SEMANAS_POR_DEFECTO,
        nivel: NivelExportacion = "resumen",
        incluir_inactivos: bool = False,
    ) -> ExportacionUso:
        if not 1 <= semanas <= SEMANAS_MAXIMAS:
            raise ValueError(f"semanas debe estar entre 1 y {SEMANAS_MAXIMAS}")
        if nivel not in ("resumen", "detalle"):
            raise ValueError("nivel debe ser 'resumen' o 'detalle'")

        desde, hasta = ventana_intervencion(fecha_inicio, semanas)
        filas_bd = self.repo.listar_uso_participantes(desde, hasta, incluir_inactivos)

        if nivel == "resumen":
            columnas, filas = self._resumen(filas_bd, fecha_inicio, semanas, incluir_inactivos)
        else:
            columnas, filas = self._detalle(filas_bd, fecha_inicio, incluir_inactivos)

        participantes = {f.codigo for f in filas_bd}
        metadatos = {
            "instrumento": "Ficha de registro de uso (Instrumento 3)",
            "fecha_inicio": fecha_inicio.isoformat(),
            "fecha_fin": (hasta - timedelta(days=1)).date().isoformat(),
            "semanas": semanas,
            "nivel": nivel,
            "incluir_inactivos": incluir_inactivos,
            "zona_horaria": "America/Lima",
            "participantes": len(participantes),
            "sesiones": sum(1 for f in filas_bd if f.fecha_hora_ingreso is not None),
            "definiciones": {
                "N": "accesos con fecha_hora_ingreso dentro de la intervencion",
                "S": "semanas de intervencion",
                "FU": "N / S",
                "T": "fecha_hora_salida - fecha_hora_ingreso (min)",
                "TPP": "suma de T / N; vacio si N = 0",
            },
        }
        return ExportacionUso(columnas=columnas, filas=filas, metadatos=metadatos)

    @staticmethod
    def _agrupar(filas_bd: List[FilaUsoParticipante]) -> Dict[str, Dict[str, Any]]:
        # Conserva el orden del repositorio (P01, P02, ..., P100).
        grupos: Dict[str, Dict[str, Any]] = {}
        for fila in filas_bd:
            grupo = grupos.setdefault(fila.codigo, {"activo": fila.activo, "sesiones": []})
            if fila.fecha_hora_ingreso is not None:
                grupo["sesiones"].append(fila)
        return grupos

    def _resumen(
        self,
        filas_bd: List[FilaUsoParticipante],
        fecha_inicio: date,
        semanas: int,
        incluir_inactivos: bool,
    ) -> Tuple[List[str], List[Dict[str, Any]]]:
        columnas_semana = [f"sem{i}" for i in range(1, semanas + 1)]
        columnas = (
            ["codigo"]
            + (["activo"] if incluir_inactivos else [])
            + ["N", "S", "FU", "sum_T_min", "TPP_min"]
            + columnas_semana
            + ["sesiones_recuperadas"]
        )

        filas = []
        for codigo, grupo in self._agrupar(filas_bd).items():
            sesiones = grupo["sesiones"]
            n = len(sesiones)
            # Suma exacta en Decimal: cada T ya viene con 2 decimales desde la BD,
            # asi que ΣT se exporta sin redondeo adicional (ni error de float).
            suma_t = sum(
                (Decimal(str(s.tiempo_permanencia_min or 0)) for s in sesiones), Decimal(0)
            )
            por_semana = {c: 0 for c in columnas_semana}
            for s in sesiones:
                semana = semana_de(s.fecha_hora_ingreso, fecha_inicio)
                clave = f"sem{semana}"
                if clave in por_semana:
                    por_semana[clave] += 1

            fila: Dict[str, Any] = {"codigo": codigo}
            if incluir_inactivos:
                fila["activo"] = grupo["activo"]
            fila.update(
                {
                    "N": n,
                    "S": semanas,
                    "FU": _redondear(n / semanas),
                    "sum_T_min": float(suma_t),
                    "TPP_min": _redondear(suma_t / n) if n else None,
                }
            )
            fila.update(por_semana)
            fila["sesiones_recuperadas"] = sum(
                1 for s in sesiones if s.tipo_cierre == "recuperada"
            )
            filas.append(fila)
        return columnas, filas

    def _detalle(
        self,
        filas_bd: List[FilaUsoParticipante],
        fecha_inicio: date,
        incluir_inactivos: bool,
    ) -> Tuple[List[str], List[Dict[str, Any]]]:
        columnas = (
            ["codigo"]
            + (["activo"] if incluir_inactivos else [])
            + [
                "n_sesion",
                "semana",
                "fecha_hora_ingreso",
                "fecha_hora_salida",
                "tiempo_permanencia_min",
                "tipo_cierre",
            ]
        )

        filas = []
        for codigo, grupo in self._agrupar(filas_bd).items():
            sesiones = sorted(grupo["sesiones"], key=lambda s: s.fecha_hora_ingreso)
            for indice, s in enumerate(sesiones, start=1):
                fila: Dict[str, Any] = {"codigo": codigo}
                if incluir_inactivos:
                    fila["activo"] = grupo["activo"]
                fila.update(
                    {
                        "n_sesion": indice,
                        "semana": semana_de(s.fecha_hora_ingreso, fecha_inicio),
                        "fecha_hora_ingreso": _iso_lima(s.fecha_hora_ingreso),
                        "fecha_hora_salida": _iso_lima(s.fecha_hora_salida),
                        "tiempo_permanencia_min": _redondear(s.tiempo_permanencia_min),
                        "tipo_cierre": s.tipo_cierre,
                    }
                )
                filas.append(fila)
        return columnas, filas
