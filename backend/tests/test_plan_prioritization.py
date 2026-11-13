from app.application.usecases.ai_support_usecases import AISupportUseCases
from app.domain.entities.support_level import SupportLevel


def _nivel(edad=5, perfil=2, contexto=2):
    return AISupportUseCases().estimate_support_level(
        edad=edad,
        diagnostico_declarado="TDAH",
        perfil_sensorial_score=perfil,
        contexto_familiar_score=contexto,
    )


def test_puntaje_critico_es_alto():
    assert _nivel(perfil=10, contexto=6) == SupportLevel.ALTO


def test_edad_menor_a_4_es_alto():
    assert _nivel(edad=3) == SupportLevel.ALTO


def test_puntaje_intermedio_es_medio():
    assert _nivel(perfil=5, contexto=4) == SupportLevel.MEDIO


def test_puntaje_bajo_es_bajo():
    assert _nivel() == SupportLevel.BAJO


def test_diagnostico_no_cambia_el_resultado():
    uc = AISupportUseCases()
    a = uc.estimate_support_level(5, "TDAH", 5, 4)
    b = uc.estimate_support_level(5, "", 5, 4)
    assert a == b
