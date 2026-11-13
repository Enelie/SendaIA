"""Registro del nino sin cuestionario de cribado (RF03, RF05).

Al eliminar el SCQ, ningun caso queda retenido: todo nino registrado llega
a la bandeja del terapeuta. La evidencia clinica solo decide si el perfil
clinico es obligatorio al vincular.
"""
from app.adapters.inbound.api.dashboard_controller import (
    RegistrarNinoRequest,
    _build_perfil_familiar,
)

CLAVES_SCQ = {"requiere_scq", "scq_completado", "scq"}


def _req(**extra):
    return RegistrarNinoRequest(nombre="Nino Prueba", fecha_nacimiento="2018-05-10", **extra)


def test_sin_diagnostico_llega_al_terapeuta_sin_cribado():
    # RF05: el diagnostico es opcional y no condiciona el envio.
    triaje = _build_perfil_familiar(_req())["triaje"]
    assert triaje == {
        "tiene_evidencia_clinica": False,
        "autorizado_envio_terapeuta": True,
        "uso_no_diagnostico": True,
    }


def test_con_diagnostico_marca_evidencia_clinica():
    triaje = _build_perfil_familiar(_req(diagnostico="TDAH"))["triaje"]
    assert triaje["tiene_evidencia_clinica"] is True
    assert triaje["autorizado_envio_terapeuta"] is True


def test_con_medicacion_o_documento_marca_evidencia_clinica():
    assert _build_perfil_familiar(_req(medicacion_actual="Metilfenidato"))["triaje"][
        "tiene_evidencia_clinica"
    ]
    assert _build_perfil_familiar(
        _req(documentos_clinicos={"informe": {"url": "/uploads/informe.pdf"}})
    )["triaje"]["tiene_evidencia_clinica"]


def test_actualizar_perfil_descarta_datos_scq_anteriores():
    perfil_actual = {
        "triaje": {
            "requiere_scq": True,
            "scq_completado": True,
            "autorizado_envio_terapeuta": False,
            "scq": {"puntaje_total": 16, "nivel_indicio": "Alto"},
        }
    }
    triaje = _build_perfil_familiar(_req(), perfil_actual)["triaje"]
    assert not CLAVES_SCQ & triaje.keys()
    assert triaje["autorizado_envio_terapeuta"] is True
