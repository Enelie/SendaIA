"""Sugerencias de actividades educativas para el panel familiar.

Selecciona actividades del catalogo existente a partir del perfil de
aprendizaje del nino (campos educativos del wizard). No usa informacion
clinica, no genera texto libre ni inventa datos: combina el modelo de
dificultad real del proyecto (motor.py) con reglas de seleccion
explicables que devuelven motivos basados en datos reales del perfil.
"""
from __future__ import annotations

import unicodedata
from datetime import date, datetime
from typing import Any, Dict, List, Tuple

from app.ai.motor import motor_adaptativo

# Campos educativos considerados para personalizar la seleccion.
CAMPOS_PERFIL = (
    "intereses",
    "nivel_atencion",
    "forma_aprende",
    "actividades_dificiles",
    "seguir_instrucciones",
    "actividades_motivan",
    "estrategias_padre",
    "distractores",
    "factores_concentracion",
    "lugar_estudio",
    "rutinas_estudio",
    "pausas",
)

#.Areas de aprendizaje dificiles -> palabras propias del catalogo.
_AREAS_DIFICILES: Tuple[Tuple[Tuple[str, ...], Tuple[str, ...]], ...] = (
    (
        ("lectura", "escribir", "texto", "letra"),
        ("comunicacion", "instruccion", "senalar", "lectura"),
    ),
    (
        ("matematica", "numero", "geometria", "cuenta"),
        ("cognitivo", "clasificacion", "color"),
    ),
)

# Formas de aprender declaradas en el wizard -> palabras del catalogo.
_FORMAS: Dict[str, Tuple[Tuple[str, ...], int]] = {
    "visual": (("visual", "seguimiento", "contacto", "color", "colores"), 4),
    "practico": (("piezas", "insertar", "clasificacion", "motricidad"), 4),
    "auditivo": (("musica", "sonido", "calibracion"), 4),
    "lectura": (("comunicacion", "instruccion", "senalar"), 3),
}

_DIFICULTAD_MAP = {"basico": "Bajo", "intermedio": "Medio", "avanzado": "Alto"}


def _norm(value: Any) -> str:
    text = str(value or "").lower()
    return "".join(
        c
        for c in unicodedata.normalize("NFKD", text)
        if not unicodedata.combining(c)
    )


def _list(value: Any) -> List[str]:
    if isinstance(value, (list, tuple, set)):
        return [str(v).strip() for v in value if str(v).strip()]
    if isinstance(value, str) and value.strip():
        return [value.strip()]
    return []


def _edad(fecha: Any) -> int:
    if not fecha:
        return 0
    if isinstance(fecha, str):
        fecha = date.fromisoformat(fecha[:10])
    if isinstance(fecha, datetime):
        fecha = fecha.date()
    hoy = date.today()
    return hoy.year - fecha.year - (
        (hoy.month, hoy.day) < (fecha.month, fecha.day)
    )


def dificultad_estimada(nino: Dict[str, Any]) -> Tuple[str, float]:
    """Nivel de dificultad real del proyecto (rf_dificultad.pkl)."""
    try:
        payload: Dict[str, Any] = {
            "nivel_cognitivo": nino.get("nivel_cognitivo") or "Bajo",
            "perfil_sensorial": nino.get("perfil_sensorial") or {},
            "objetivos_intervencion": nino.get("objetivos_intervencion") or [],
        }
        if nino.get("fecha_nacimiento"):
            payload["fecha_nacimiento"] = nino["fecha_nacimiento"]
        dificultad, confianza = motor_adaptativo.predecir_dificultad(payload)
        return _DIFICULTAD_MAP.get(_norm(dificultad), "Medio"), float(
            confianza or 0.0
        )
    except Exception:
        edad = _edad(nino.get("fecha_nacimiento"))
        nivel = _norm(nino.get("nivel_cognitivo"))
        if nivel == "alto":
            return "Alto", 0.5
        if edad and edad < 7:
            return "Bajo", 0.5
        return "Medio", 0.5


def _perfil_educativo(nino: Dict[str, Any]) -> Dict[str, Any]:
    """Extrae solo campos educativos del perfil (nada clinico)."""
    perfil = nino.get("perfil_sensorial")
    if not isinstance(perfil, dict):
        perfil = {}
    hitos = perfil.get("hitos")
    hitos = hitos if isinstance(hitos, dict) else {}
    sensorial = perfil.get("sensorial")
    sensorial = sensorial if isinstance(sensorial, dict) else {}

    distractores = _list(sensorial.get("distractores"))
    # Compatibilidad con perfiles antiguos guardados en la misma columna.
    for key in ("hipersensibilidad", "hiposensibilidad"):
        distractores.extend(_list(sensorial.get(key)))
        distractores.extend(_list(perfil.get(key)))

    return {
        "intereses": _list(perfil.get("intereses")),
        "nivel_atencion": str(hitos.get("atencion") or ""),
        "forma_aprende": _list(hitos.get("forma_aprende")),
        "actividades_dificiles": _list(hitos.get("actividades_dificiles")),
        "seguir_instrucciones": str(hitos.get("seguir_instrucciones") or ""),
        "actividades_motivan": _list(hitos.get("actividades_motivan")),
        "estrategias_padre": _list(hitos.get("estrategias_padre")),
        "distractores": distractores,
        "factores_concentracion": _list(
            sensorial.get("factores_concentracion")
        ),
        "lugar_estudio": str(sensorial.get("lugar_estudio") or ""),
        "rutinas_estudio": _list(sensorial.get("rutinas_estudio")),
        "pausas": str(sensorial.get("pausas") or ""),
    }


def _puntuar(
    actividad: Dict[str, Any],
    perfil: Dict[str, Any],
    dificultad: str,
) -> Tuple[int, List[str], List[str]]:
    texto = _norm(
        " ".join(
            [
                str(actividad.get("tipo") or ""),
                str(actividad.get("nombre") or ""),
                str(actividad.get("instrucciones") or ""),
            ]
        )
    )
    tipo = _norm(actividad.get("tipo"))
    nivel = str(actividad.get("nivel_dificultad") or "Medio")
    try:
        duracion = int(actividad.get("duracion_estimada") or 0)
    except (TypeError, ValueError):
        duracion = 0

    score = 0
    motivos: List[str] = []
    consejos: List[str] = []

    # 1) Dificultad estimada por el modelo del proyecto.
    if nivel == dificultad:
        score += 8
        motivos.append(
            f"Dificultad {nivel}, acorde al nivel estimado para el nino"
        )
    elif dificultad == "Medio":
        score += 3
    elif nivel == "Medio":
        score += 2

    # 2) Intereses declarados en el perfil.
    for interes in perfil["intereses"]:
        token = _norm(interes)
        if len(token) >= 4 and token in texto:
            score += 7
            motivos.append(f"Se conecta con su interes en {interes}")
            break

    # 3) Actividades que lo motivan.
    for frase in perfil["actividades_motivan"]:
        palabras = [w for w in _norm(frase).split() if len(w) >= 5]
        if any(p in texto for p in palabras):
            score += 5
            motivos.append(
                f"Coincide con actividades que lo motivan ({frase})"
            )
            break

    # 4) Areas de aprendizaje que le resultan dificiles.
    dificiles = _norm(" ".join(perfil["actividades_dificiles"]))
    if dificiles:
        for triggers, objetivos in _AREAS_DIFICILES:
            if any(t in dificiles for t in triggers) and any(
                o in texto for o in objetivos
            ):
                score += 5
                motivos.append(
                    "Refuerza una de las areas que le resultan dificiles"
                )
                break

    # 5) Nivel de atencion vs duracion.
    atencion = _norm(perfil["nivel_atencion"]) or "moderado"
    if atencion == "bajo":
        if duracion and duracion <= 300:
            score += 4
            motivos.append(
                "Duracion corta, adecuada a su nivel de atencion"
            )
        elif duracion >= 600:
            score -= 5
    elif atencion == "alto" and duracion >= 600:
        score += 2
        motivos.append("Le da tiempo para sostener la actividad")

    # 6) Necesidad de pausas vs duracion.
    pausas = _norm(perfil["pausas"])
    if "con frecuencia" in pausas:
        if duracion and duracion <= 300:
            score += 2
            motivos.append("Facil de dividir en pausas cortas")
        elif duracion >= 600:
            score -= 4
        consejos.append("Ofrece una pausa breve si lo necesita.")

    # 7) Distractores del entorno de estudio.
    if any("ruido" in _norm(d) for d in perfil["distractores"]):
        if "musica" in texto or "sonido" in texto:
            score -= 6
    if any(
        "demasiados estimulos" in _norm(f)
        for f in perfil["factores_concentracion"]
    ):
        if nivel == "Alto":
            score -= 3

    # 8) Forma en que aprende mejor.
    for forma in perfil["forma_aprende"]:
        normalizada = _norm(forma)
        for clave, (objetivos, puntos) in _FORMAS.items():
            if clave in normalizada and any(o in texto for o in objetivos):
                score += puntos
                motivos.append(
                    f"Se ajusta a su forma de aprender ({forma.split('(')[0].strip()})"
                )
                break
        else:
            continue
        break

    # 9) Capacidad para seguir instrucciones.
    instrucciones = _norm(perfil["seguir_instrucciones"])
    if "paso a paso" in instrucciones or "cuesta" in instrucciones:
        if nivel == "Bajo":
            score += 3
            motivos.append(
                "Instrucciones simples, ideal para ir paso a paso"
            )
    elif (
        "varios pasos" in instrucciones or "varias pasos" in instrucciones
    ) and nivel == "Alto":
        score += 3
        motivos.append("Retos con varios pasos, acordes a su capacidad")

    # Consejos para el padre, solo si el perfil los declara.
    if perfil["lugar_estudio"]:
        consejos.append(f"Realizala en: {perfil['lugar_estudio']}.")
    if perfil["estrategias_padre"]:
        consejos.append(
            f"Aplica tu estrategia: {perfil['estrategias_padre'][0]}."
        )
    if perfil["rutinas_estudio"]:
        consejos.append(f"Respeta tu rutina: {perfil['rutinas_estudio'][0]}.")
    factores = [_norm(f) for f in perfil["factores_concentracion"]]
    if any(f in factores for f in ("poco sueno", "cansancio", "hambre")):
        consejos.append(
            "Revisa que este descansado y alimentado antes de empezar."
        )

    motivos = motivos[:3] or [
        f"Actividad de dificultad {nivel}, acorde al nivel estimado"
    ]
    return score, motivos, consejos[:3]


def construir_sugerencias(
    nino: Dict[str, Any],
    catalogo: List[Dict[str, Any]],
    limite: int = 3,
) -> Dict[str, Any]:
    """Selecciona las mejores actividades del catalogo para el perfil."""
    perfil = _perfil_educativo(nino)
    dificultad, confianza = dificultad_estimada(nino)
    campos = [c for c in CAMPOS_PERFIL if perfil.get(c)]

    puntuadas: List[Tuple[int, Dict[str, Any], List[str], List[str]]] = []
    for actividad in catalogo or []:
        if not actividad.get("activo", True):
            continue
        score, motivos, consejos = _puntuar(actividad, perfil, dificultad)
        puntuadas.append((score, actividad, motivos, consejos))

    puntuadas.sort(
        key=lambda item: (-item[0], _norm(item[1].get("nombre")))
    )

    sugerencias = []
    for score, actividad, motivos, consejos in puntuadas[:limite]:
        try:
            duracion = int(actividad.get("duracion_estimada") or 0)
        except (TypeError, ValueError):
            duracion = 0
        recursos = actividad.get("recursos_multimedia")
        materiales = []
        if isinstance(recursos, dict):
            materiales = _list(recursos.get("materiales"))
        sugerencias.append(
            {
                "actividad_id": str(actividad.get("id")),
                "nombre": actividad.get("nombre"),
                "tipo": actividad.get("tipo"),
                "nivel_dificultad": actividad.get("nivel_dificultad"),
                "duracion_segundos": duracion,
                "duracion_minutos": round(duracion / 60)
                if duracion
                else None,
                "instrucciones": actividad.get("instrucciones"),
                "materiales": materiales,
                "puntuacion": score,
                "motivos": motivos,
                "consejos": consejos,
            }
        )

    return {
        "nino_id": str(nino.get("id") or ""),
        "nino_nombre": nino.get("nombre"),
        "dificultad_estimada": dificultad,
        "confianza_modelo": round(confianza, 3),
        "perfil_completo": len(campos) >= 4,
        "campos_perfil_usados": campos,
        "sugerencias": sugerencias,
        "total_catalogo": len(catalogo or []),
        "nota": (
            "Sugerencias seleccionadas a partir del perfil de aprendizaje "
            "y el modelo de dificultad del proyecto. No constituyen "
            "indicacion clinica ni diagnostico."
        ),
    }
