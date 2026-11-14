"""Utilidades para corregir texto con mojibake (UTF-8 leido como Latin-1).

Algunos registros antiguos guardaron tildes y enes como ``Ã³``, ``Ã¡`` o
``SÃ­`` porque el texto UTF-8 se interpreto como Windows-1252/Latin-1.
Estas funciones revierten ese efecto sin tocar el texto que ya es valido.
"""
from __future__ import annotations

from typing import Any

# Marcadores tipicos de UTF-8 interpretado como Latin-1/Windows-1252.
_MARCADORES = ("Ã", "Â", "â€", "ï¿½")


def reparar_texto(valor: str) -> str:
    """Devuelve el texto corregido si detecta mojibake; si no, lo deja igual."""
    if not valor or not any(marcador in valor for marcador in _MARCADORES):
        return valor

    for encoding in ("cp1252", "latin-1"):
        try:
            return valor.encode(encoding).decode("utf-8")
        except (UnicodeEncodeError, UnicodeDecodeError):
            continue
    return valor


def reparar_estructura(valor: Any) -> Any:
    """Aplica :func:`reparar_texto` a strings dentro de listas y diccionarios."""
    if isinstance(valor, str):
        return reparar_texto(valor)
    if isinstance(valor, list):
        return [reparar_estructura(item) for item in valor]
    if isinstance(valor, tuple):
        return tuple(reparar_estructura(item) for item in valor)
    if isinstance(valor, dict):
        return {
            reparar_texto(str(clave)): reparar_estructura(item)
            for clave, item in valor.items()
        }
    return valor
