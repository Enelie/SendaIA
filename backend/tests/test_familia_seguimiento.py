"""Seguimiento familiar: autorización y forma de GET /api/dashboard/familia/ninos/{id}/seguimiento."""
from contextlib import contextmanager
from datetime import date, datetime, timezone
from unittest.mock import MagicMock, patch

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.adapters.inbound.api import familia_seguimiento_controller as ctrl
from app.adapters.inbound.api.dependencies import get_current_user

NINO = "cccccccc-0000-0000-0000-000000000004"
TUTOR_USER = {"id": "11111111-0000-0000-0000-000000000003", "role": "padre_tutor"}


def _client(user):
    app = FastAPI()
    app.include_router(ctrl.router)
    app.dependency_overrides[get_current_user] = lambda: user
    return TestClient(app)


def _mock_conn(fetchone_values, fetchall_values):
    cur = MagicMock()
    cur.fetchone.side_effect = fetchone_values
    cur.fetchall.side_effect = fetchall_values
    conn = MagicMock()
    conn.cursor.return_value.__enter__ = MagicMock(return_value=cur)
    conn.cursor.return_value.__exit__ = MagicMock(return_value=False)

    @contextmanager
    def fake():
        yield conn

    return fake, cur


def _url(**params):
    query = "&".join(f"{k}={v}" for k, v in params.items())
    return f"/api/dashboard/familia/ninos/{NINO}/seguimiento" + (f"?{query}" if query else "")


@pytest.mark.parametrize("role", ["terapeuta", "admin"])
def test_rechaza_roles_no_familiares(role):
    fake, cur = _mock_conn([], [])
    with patch.object(ctrl, "get_connection", fake):
        res = _client({"id": "x", "role": role}).get(_url())
    assert res.status_code == 403
    cur.execute.assert_not_called()


def test_nino_de_otra_familia_devuelve_404():
    fake, cur = _mock_conn([None], [])
    with patch.object(ctrl, "get_connection", fake):
        res = _client(TUTOR_USER).get(_url())
    assert res.status_code == 404
    # La pertenencia se valida en BD con el usuario del token, no con datos del cliente.
    sql, params = cur.execute.call_args_list[0].args
    assert "t.usuario_id = %s" in sql
    assert params == (NINO, TUTOR_USER["id"])


def test_id_invalido_no_llega_a_la_bd():
    fake, cur = _mock_conn([], [])
    with patch.object(ctrl, "get_connection", fake):
        res = _client(TUTOR_USER).get("/api/dashboard/familia/ninos/no-es-uuid/seguimiento")
    assert res.status_code == 404
    cur.execute.assert_not_called()


@pytest.mark.parametrize(
    "params",
    [
        {"desde": "2026-13-01"},
        {"desde": "2026-05-10", "hasta": "2026-05-01"},
        {"desde": "2020-01-01", "hasta": "2026-01-01"},
    ],
)
def test_valida_rango_de_fechas(params):
    fake, cur = _mock_conn([], [])
    with patch.object(ctrl, "get_connection", fake):
        res = _client(TUTOR_USER).get(_url(**params))
    assert res.status_code == 422
    cur.execute.assert_not_called()


def test_respuesta_con_registros_y_recomendadas():
    fecha = datetime(2026, 10, 21, 0, 33, tzinfo=timezone.utc)
    registro = {
        "registro_id": "r1", "sesion_id": "s1", "plan_id": "p1",
        "fecha_inicio": fecha, "estado": "completada", "origen_registro": "familia_app",
        "actividad_id": "a1", "actividad_nombre": "Lectura guiada", "actividad_tipo": "Lectura",
        "duracion_estimada": 600, "duracion_segundos": 420.0, "aciertos": 4, "repeticiones": 5,
        "nivel_ayuda_requerido": 1, "nivel_dificultad_usado": "Medio", "observaciones": "Bien",
    }
    totales = {
        "actividades_completadas": 1, "dias_con_actividad": 1, "segundos_totales": 420.0,
        "registros_con_duracion": 1, "aciertos": 4, "intentos": 5,
    }
    semanas = [{"semana": date(2026, 10, 19), "actividades": 1, "segundos": 420.0}]
    recomendadas = [
        {"plan_id": "p1", "actividad_id": "a1", "nombre": "Lectura guiada", "tipo": "Lectura",
         "duracion_estimada": 600, "ultima_realizacion": fecha},
        {"plan_id": "p1", "actividad_id": "a2", "nombre": "Puzzle", "tipo": "Logica",
         "duracion_estimada": 300, "ultima_realizacion": None},
    ]
    fake, cur = _mock_conn(
        [{"id": NINO, "nombre": "Diego"}, totales],
        [[registro], semanas, recomendadas],
    )
    with patch.object(ctrl, "get_connection", fake):
        res = _client(TUTOR_USER).get(_url(desde="2026-10-01", hasta="2026-10-28"))

    assert res.status_code == 200
    body = res.json()
    assert body["desde"] == "2026-10-01" and body["hasta"] == "2026-10-28"
    assert body["resumen"]["actividades_completadas"] == 1
    assert body["por_semana"] == [{"semana": "2026-10-19", "actividades": 1, "segundos": 420.0}]
    reg = body["registros"][0]
    assert reg["actividad_nombre"] == "Lectura guiada"
    assert reg["duracion_segundos"] == 420.0
    assert reg["intentos"] == 5
    assert [r["realizada"] for r in body["recomendadas"]] == [True, False]
    assert body["registros_truncados"] is False

    # Todas las consultas filtran por el niño autorizado; el rango es [desde, hasta+1).
    for call in cur.execute.call_args_list[1:4]:
        assert call.args[1][0] == NINO
    assert cur.execute.call_args_list[1].args[1][1:3] == (date(2026, 10, 1), date(2026, 10, 29))


def test_duracion_solo_para_registros_de_la_app_familiar():
    assert "familia_app" in ctrl.DURACION_SQL
    assert "familia_app_offline" in ctrl.DURACION_SQL
