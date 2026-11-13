from app.domain.entities.support_level import SupportLevel


class AISupportUseCases:
    """Estimador heuristico del nivel de apoyo (respuesta en < 100 ms).

    No usa cuestionarios de cribado ni niveles de severidad: el sistema no
    infiere ni diagnostica (RF05/RF24). diagnostico_declarado se conserva en la
    firma por compatibilidad con /api/v1/ai/estimar-apoyo, pero no se usa.
    """

    def estimate_support_level(
        self,
        edad: int,
        diagnostico_declarado: str,
        perfil_sensorial_score: int,
        contexto_familiar_score: int,
    ) -> SupportLevel:
        score = perfil_sensorial_score + contexto_familiar_score
        if score > 15 or edad < 4:
            return SupportLevel.ALTO
        if score > 8:
            return SupportLevel.MEDIO
        return SupportLevel.BAJO
