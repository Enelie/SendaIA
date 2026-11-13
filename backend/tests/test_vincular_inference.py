from app.adapters.inbound.api.dashboard_controller import (
    NIVEL_ACOMPANAMIENTO_SIN_DATOS,
    _infer_nivel_acompanamiento,
    _modo_ejecucion_por_acompanamiento,
    _objetivos_desde_perfil,
)


def _perfil(**hitos):
    return {"hitos": hitos}


def test_sin_datos_rf07_sugiere_acompanada():
    assert _infer_nivel_acompanamiento({}) == NIVEL_ACOMPANAMIENTO_SIN_DATOS == 2
    assert _infer_nivel_acompanamiento(None) == 2


def test_atencion_alta_y_varios_pasos_es_autonoma():
    perfil = _perfil(atencion="Alto", seguir_instrucciones="Sigue instrucciones de varias pasos")
    assert _infer_nivel_acompanamiento(perfil) == 1


def test_atencion_moderada_e_instrucciones_simples_es_acompanada():
    perfil = _perfil(atencion="Moderado", seguir_instrucciones="Sigue instrucciones simples")
    assert _infer_nivel_acompanamiento(perfil) == 2


def test_atencion_baja_y_le_cuesta_es_continuo():
    perfil = _perfil(atencion="Bajo", seguir_instrucciones="Le cuesta seguir instrucciones")
    assert _infer_nivel_acompanamiento(perfil) == 3


def test_apoyo_de_otra_persona_y_dificultades_suben_el_nivel():
    base = _perfil(atencion="Moderado", seguir_instrucciones="Sigue instrucciones simples")
    assert _infer_nivel_acompanamiento(base) == 2
    base["hitos"]["forma_aprende"] = ["Con apoyo de otra persona"]
    base["hitos"]["actividades_dificiles"] = ["Leer", "Escribir", "Matematicas"]
    assert _infer_nivel_acompanamiento(base) == 3


def test_el_diagnostico_no_influye():
    # RF05/RF24: el nivel solo depende de RF07, nunca del texto del diagnostico.
    perfil = _perfil(atencion="Alto", seguir_instrucciones="Sigue instrucciones de varias pasos")
    perfil["diagnostico"] = "nivel 3"
    assert _infer_nivel_acompanamiento(perfil) == 1


def test_modo_ejecucion_por_nivel():
    assert _modo_ejecucion_por_acompanamiento(1) == {
        "modo_ejecucion": "autonoma",
        "requiere_acompanamiento": False,
    }
    assert _modo_ejecucion_por_acompanamiento(2)["requiere_acompanamiento"] is True
    assert _modo_ejecucion_por_acompanamiento(3)["modo_ejecucion"] == "acompanada"


def test_objetivos_desde_perfil_comunicacion():
    perfil = {
        "hitos": {
            "comunicacion": "Habla palabras sueltas"
        }
    }
    objs = _objetivos_desde_perfil(perfil)
    assert "Fortalecer comunicacion funcional (Habla palabras sueltas)." in objs


def test_objetivos_desde_perfil_rutinas():
    perfil = {
        "rutinas_regulacion": ["mecerse en hamaca"]
    }
    objs = _objetivos_desde_perfil(perfil)
    assert "Usar rutinas de regulacion registradas por la familia." in objs


def test_objetivos_desde_perfil_sensorial():
    perfil = {
        "sensorial": {
            "hipersensibilidad": ["ruidos"]
        }
    }
    objs = _objetivos_desde_perfil(perfil)
    assert "Adaptar actividades a sensibilidades y estimulos aversivos." in objs


def test_objetivos_desde_perfil_intereses():
    perfil = {
        "intereses": ["trenes"]
    }
    objs = _objetivos_desde_perfil(perfil)
    assert "Incorporar intereses del nino como motivadores terapeuticos." in objs


def test_objetivos_desde_perfil_default():
    objs = _objetivos_desde_perfil({})
    assert "Fortalecer comunicacion funcional." in objs
    assert "Mejorar tolerancia a actividades guiadas." in objs
