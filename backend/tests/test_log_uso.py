"""Instrumento 3: calculo de FU/TPP, sincronizacion idempotente y permisos de logs de uso."""
import csv
import io
import json
from datetime import date, datetime, timedelta, timezone
from unittest.mock import MagicMock
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.adapters.inbound.api import log_uso_controller as ctrl
from app.adapters.inbound.api.dependencies import (
    get_auditoria_repository,
    get_current_user,
    get_exportar_log_uso_usecase,
    get_sincronizar_log_uso_usecase,
)
from app.application.ports.log_uso_repository import ILogUsoRepository
from app.application.usecases.exportar_log_uso_usecase import (
    ExportarLogUsoUseCase,
    semana_de,
    ventana_intervencion,
)
from app.application.usecases.sincronizar_log_uso_usecase import SincronizarLogUsoUseCase
from app.domain.entities.log_uso import EventoUso, FilaUsoParticipante

LIMA = timezone(timedelta(hours=-5))
INICIO = date(2026, 3, 2)  # lunes
AHORA = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)
TUTOR = {"id": "11111111-0000-0000-0000-000000000003", "role": "padre_tutor"}
ADMIN = {"id": "11111111-0000-0000-0000-000000000001", "role": "admin"}


class RepoFalso(ILogUsoRepository):
    def __init__(self, filas=None, resultados=None):
        self.filas = filas or []
        self.resultados = resultados or {}
        self.llamadas_registro = []
        self.llamadas_listado = []

    def registrar_eventos(self, usuario_id, rol_usuario, eventos):
        self.llamadas_registro.append((usuario_id, rol_usuario, eventos))
        return {
            str(e.client_event_id): self.resultados.get(str(e.client_event_id), "insertado")
            for e in eventos
        }

    def listar_uso_participantes(self, desde, hasta, incluir_inactivos):
        self.llamadas_listado.append((desde, hasta, incluir_inactivos))
        return self.filas


def _sesion(codigo, ingreso, minutos, tipo="logout", activo=True):
    return FilaUsoParticipante(
        codigo=codigo,
        activo=activo,
        fecha_hora_ingreso=ingreso,
        fecha_hora_salida=ingreso + timedelta(minutes=minutos),
        tiempo_permanencia_min=float(minutos),
        tipo_cierre=tipo,
    )


def _sin_sesiones(codigo, activo=True):
    return FilaUsoParticipante(codigo=codigo, activo=activo)


def _evento(ingreso=None, minutos=10, **extra):
    ingreso = ingreso or datetime(2026, 3, 3, 15, 0, tzinfo=timezone.utc)
    datos = {
        "client_event_id": str(uuid4()),
        "fecha_hora_ingreso": ingreso.isoformat(),
        "fecha_hora_salida": (ingreso + timedelta(minutes=minutos)).isoformat(),
        "tipo_cierre": "logout",
    }
    datos.update(extra)
    return datos


# ---------------------------------------------------------------------------
# Ventana y semanas
# ---------------------------------------------------------------------------

def test_ventana_de_8_semanas_en_hora_de_lima():
    desde, hasta = ventana_intervencion(INICIO, 8)
    assert desde.utcoffset() == timedelta(hours=-5)
    assert desde.replace(tzinfo=None) == datetime(2026, 3, 2, 0, 0)
    assert hasta.replace(tzinfo=None) == datetime(2026, 4, 27, 0, 0)


def test_semana_se_asigna_por_fecha_de_lima_no_utc():
    # 2026-03-09 03:00 UTC = domingo 2026-03-08 22:00 en Lima -> semana 1, no 2.
    assert semana_de(datetime(2026, 3, 9, 3, 0, tzinfo=timezone.utc), INICIO) == 1
    assert semana_de(datetime(2026, 3, 9, 5, 0, tzinfo=timezone.utc), INICIO) == 2


# ---------------------------------------------------------------------------
# Calculo de FU y TPP
# ---------------------------------------------------------------------------

def test_resumen_calcula_n_fu_y_tpp():
    t0 = datetime(2026, 3, 2, 10, 0, tzinfo=LIMA)
    repo = RepoFalso(
        [
            _sesion("P01", t0, 10),
            _sesion("P01", t0 + timedelta(days=8), 20),
            _sesion("P01", t0 + timedelta(days=50), 30, tipo="recuperada"),
        ]
    )
    exp = ExportarLogUsoUseCase(repo).execute(INICIO, 8, "resumen")
    fila = exp.filas[0]
    assert fila["N"] == 3
    assert fila["S"] == 8
    assert fila["FU"] == 0.38  # 3/8 = 0.375, redondeo medio hacia arriba
    assert fila["sum_T_min"] == 60.0
    assert fila["TPP_min"] == 20.0
    assert (fila["sem1"], fila["sem2"], fila["sem8"]) == (1, 1, 1)
    assert sum(fila[f"sem{i}"] for i in range(1, 9)) == fila["N"]
    assert fila["sesiones_recuperadas"] == 1


def test_suma_t_es_exacta_sin_redondeo_adicional():
    # Con floats, 10.1 + 20.2 = 30.299999999999997; ΣT debe ser la suma exacta de los T de la BD.
    t0 = datetime(2026, 3, 2, 10, 0, tzinfo=LIMA)
    repo = RepoFalso([_sesion("P01", t0, 10.1), _sesion("P01", t0 + timedelta(hours=2), 20.2)])
    fila = ExportarLogUsoUseCase(repo).execute(INICIO, 8, "resumen").filas[0]
    assert fila["sum_T_min"] == 30.3
    assert fila["TPP_min"] == 15.15


def test_participante_sin_uso_aparece_con_n_cero_y_tpp_vacio():
    t0 = datetime(2026, 3, 2, 10, 0, tzinfo=LIMA)
    repo = RepoFalso([_sesion("P01", t0, 15), _sin_sesiones("P02")])
    exp = ExportarLogUsoUseCase(repo).execute(INICIO, 8, "resumen")
    p02 = next(f for f in exp.filas if f["codigo"] == "P02")
    assert p02["N"] == 0
    assert p02["FU"] == 0.0
    assert p02["TPP_min"] is None
    assert exp.metadatos["participantes"] == 2


def test_detalle_numera_sesiones_por_participante():
    t0 = datetime(2026, 3, 2, 10, 0, tzinfo=LIMA)
    repo = RepoFalso(
        [_sesion("P01", t0 + timedelta(days=1), 5), _sesion("P01", t0, 7), _sin_sesiones("P02")]
    )
    exp = ExportarLogUsoUseCase(repo).execute(INICIO, 8, "detalle")
    assert [(f["codigo"], f["n_sesion"], f["tiempo_permanencia_min"]) for f in exp.filas] == [
        ("P01", 1, 7.0),
        ("P01", 2, 5.0),
    ]
    assert exp.filas[0]["fecha_hora_ingreso"].endswith("-05:00")


def test_incluir_inactivos_se_pasa_al_repositorio_y_agrega_columna():
    repo = RepoFalso([_sin_sesiones("P01", activo=False)])
    uc = ExportarLogUsoUseCase(repo)
    sin = uc.execute(INICIO, 8, "resumen")
    con = uc.execute(INICIO, 8, "resumen", incluir_inactivos=True)
    assert repo.llamadas_listado[0][2] is False
    assert repo.llamadas_listado[1][2] is True
    assert "activo" not in sin.columnas
    assert "activo" in con.columnas


def test_semanas_fuera_de_rango():
    uc = ExportarLogUsoUseCase(RepoFalso())
    with pytest.raises(ValueError):
        uc.execute(INICIO, 0)


# ---------------------------------------------------------------------------
# Sincronizacion
# ---------------------------------------------------------------------------

def _uc_sync(repo):
    return SincronizarLogUsoUseCase(repo, ahora=lambda: AHORA)


def test_sync_valida_eventos_y_acepta_duplicados():
    duplicado = _evento()
    repo = RepoFalso(resultados={duplicado["client_event_id"]: "duplicado"})
    eventos = [
        EventoUso(**_evento()),
        EventoUso(**duplicado),
        EventoUso(**_evento(minutos=-5)),
        EventoUso(**_evento(ingreso=AHORA + timedelta(hours=1))),
        EventoUso(**_evento(minutos=13 * 60)),
        EventoUso(**_evento(ingreso=datetime(2026, 3, 3, 10, 0))),  # sin zona horaria
    ]
    res = _uc_sync(repo).execute(TUTOR["id"], "padre_tutor", eventos)
    assert len(res.aceptados) == 2
    assert duplicado["client_event_id"] in res.aceptados
    assert sorted(r["motivo"] for r in res.rechazados) == [
        "duracion_excede_12h",
        "fecha_sin_zona_horaria",
        "ingreso_en_el_futuro",
        "salida_anterior_a_ingreso",
    ]
    # Solo los validos llegan a la BD.
    assert len(repo.llamadas_registro[0][2]) == 2


def test_sync_conflicto_y_error_transitorio():
    conflicto, transitorio = _evento(), _evento()
    repo = RepoFalso(
        resultados={
            conflicto["client_event_id"]: "conflicto",
            transitorio["client_event_id"]: "error",
        }
    )
    res = _uc_sync(repo).execute(
        TUTOR["id"], "padre_tutor", [EventoUso(**conflicto), EventoUso(**transitorio)]
    )
    assert res.aceptados == []
    assert res.rechazados == [
        {"client_event_id": conflicto["client_event_id"], "motivo": "client_event_id_de_otro_usuario"}
    ]
    assert res.reintentar == [transitorio["client_event_id"]]


def test_sync_ignora_repetidos_en_el_mismo_lote():
    evento = _evento()
    repo = RepoFalso()
    res = _uc_sync(repo).execute(TUTOR["id"], "padre_tutor", [EventoUso(**evento), EventoUso(**evento)])
    assert res.aceptados == [evento["client_event_id"]]
    assert len(repo.llamadas_registro[0][2]) == 1


# ---------------------------------------------------------------------------
# Endpoints: permisos y seudonimizacion
# ---------------------------------------------------------------------------

def _client(user, repo=None, auditoria=None):
    repo = repo or RepoFalso()
    app = FastAPI()
    app.state.limiter = ctrl.limiter
    app.include_router(ctrl.router)
    app.dependency_overrides[get_current_user] = lambda: user
    app.dependency_overrides[get_sincronizar_log_uso_usecase] = lambda: SincronizarLogUsoUseCase(repo)
    app.dependency_overrides[get_exportar_log_uso_usecase] = lambda: ExportarLogUsoUseCase(repo)
    app.dependency_overrides[get_auditoria_repository] = lambda: auditoria or MagicMock()
    return TestClient(app)


@pytest.mark.parametrize("role", ["admin", "terapeuta"])
def test_sync_rechaza_roles_no_familiares(role):
    repo = RepoFalso()
    res = _client({"id": "x", "role": role}, repo).post("/api/v1/logs/uso/sync", json={"eventos": [_evento()]})
    assert res.status_code == 403
    assert repo.llamadas_registro == []


def test_sync_usa_usuario_del_token_e_ignora_el_del_cuerpo():
    repo = RepoFalso()
    ingreso = datetime.now(timezone.utc) - timedelta(hours=1)
    evento = _evento(ingreso=ingreso, usuario_id="99999999-0000-0000-0000-000000000099")
    res = _client(TUTOR, repo).post("/api/v1/logs/uso/sync", json={"eventos": [evento]})
    assert res.status_code == 200
    assert res.json()["aceptados"] == [evento["client_event_id"]]
    usuario_id, rol, _ = repo.llamadas_registro[0]
    assert usuario_id == TUTOR["id"]
    assert rol == "padre_tutor"


def test_sync_rechaza_lote_demasiado_grande():
    res = _client(TUTOR).post("/api/v1/logs/uso/sync", json={"eventos": [_evento() for _ in range(201)]})
    assert res.status_code == 422


@pytest.mark.parametrize("role", ["padre_tutor", "terapeuta"])
def test_export_solo_admin(role):
    res = _client({"id": "x", "role": role}).get(f"/api/v1/logs/export?fecha_inicio={INICIO}")
    assert res.status_code == 403


def test_export_csv_seudonimizado_y_auditado():
    t0 = datetime(2026, 3, 2, 10, 0, tzinfo=LIMA)
    repo = RepoFalso([_sesion("P01", t0, 12.5), _sin_sesiones("P02")])
    auditoria = MagicMock()
    res = _client(ADMIN, repo, auditoria).get(f"/api/v1/logs/export?fecha_inicio={INICIO}")
    assert res.status_code == 200
    assert res.headers["content-type"].startswith("text/csv")
    assert res.headers["cache-control"] == "no-store"
    cuerpo = res.content.decode("utf-8")
    assert cuerpo.startswith("﻿")
    filas = list(csv.DictReader(io.StringIO(cuerpo.lstrip("﻿"))))
    assert [f["codigo"] for f in filas] == ["P01", "P02"]
    assert filas[1]["TPP_min"] == ""  # N = 0 -> vacio, no 0
    assert "usuario_id" not in cuerpo
    assert TUTOR["id"] not in cuerpo
    # Exportacion trazada en logs_auditoria.
    log = auditoria.log_action.call_args.args[0]
    assert log.accion == "EXPORT_LOG_USO"
    assert log.usuario_id == ADMIN["id"]
    assert json.loads(log.payload_nuevo)["participantes"] == 2


def test_export_json_y_si_falla_auditoria_no_se_entrega():
    repo = RepoFalso([_sin_sesiones("P01")])
    ok = _client(ADMIN, repo).get(f"/api/v1/logs/export?fecha_inicio={INICIO}&formato=json&nivel=detalle")
    assert ok.status_code == 200
    assert ok.json()["metadatos"]["semanas"] == 8

    auditoria = MagicMock()
    auditoria.log_action.side_effect = RuntimeError("bd caida")
    cliente = _client(ADMIN, repo, auditoria)
    url = f"/api/v1/logs/export?fecha_inicio={INICIO}"
    with pytest.raises(RuntimeError):
        cliente.get(url)
