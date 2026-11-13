import '../../domain/entities/log_uso_local.dart';

/// Almacenamiento local (SQLite) de las sesiones de uso.
abstract class ILogUsoLocalPort {
  /// Inserta o reemplaza la sesión (por id).
  Future<void> guardarSesionUso(LogUsoLocal sesion);

  /// Sesiones abiertas o cerradas por segundo plano, no rechazadas,
  /// de la más reciente a la más antigua. Se usan para recuperar el estado
  /// al arrancar la app.
  Future<List<LogUsoLocal>> sesionesUsoAbiertasOEnPausa();

  /// Sesiones cerradas de forma definitiva del [usuarioId], listas para subir:
  /// cerradas por logout/recuperada, o por segundo plano con salida anterior
  /// o igual a [finGracia] (ya no pueden reabrirse).
  Future<List<LogUsoLocal>> sesionesUsoListasParaSync({
    required String usuarioId,
    required DateTime finGracia,
    int limite = 200,
  });

  Future<void> eliminarSesionesUso(List<String> ids);

  /// Rechazo permanente del servidor: se conservan para el registro de
  /// incidencias, pero no se reintentan.
  Future<void> marcarSesionesUsoRechazadas(Map<String, String> motivos);

  Future<void> registrarFalloSyncUso(List<String> ids, String error);
}

class ResultadoSyncUso {
  final List<String> aceptados;
  final Map<String, String> rechazados;

  const ResultadoSyncUso({required this.aceptados, required this.rechazados});
}

/// Envío de sesiones de uso al backend.
abstract class ILogUsoRemotePort {
  /// Lanza una excepción si no hay red o el servidor no respondió 2xx;
  /// en ese caso las sesiones se quedan en la cola local.
  Future<ResultadoSyncUso> enviarSesionesUso(List<LogUsoLocal> sesiones);
}
