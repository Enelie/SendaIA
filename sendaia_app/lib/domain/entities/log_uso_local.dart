/// Sesión de uso del aplicativo registrada en el dispositivo (Instrumento 3).
///
/// Un acceso = una fila. Se guarda primero en SQLite y se sube después a
/// `logs_uso` mediante `POST /api/v1/logs/uso/sync`.
/// Ver docs/06_logs_y_metricas.md.
library;

/// Si el padre vuelve antes de este plazo, se continúa la misma sesión
/// (salir 10 s a otra app no cuenta como un acceso nuevo).
const Duration kPeriodoGraciaUso = Duration(minutes: 5);

/// Cada cuánto se marca "sigo aquí" mientras la app está en primer plano.
/// Si la app se cierra a la fuerza, la salida se estima con el último latido.
const Duration kIntervaloLatidoUso = Duration(seconds: 60);

/// Solo los padres/tutores forman parte de la muestra.
const Set<String> kRolesRegistradosUso = {'padre_tutor', 'tutor'};

class LogUsoLocal {
  static const String cierreLogout = 'logout';
  static const String cierreSegundoPlano = 'segundo_plano';
  static const String cierreRecuperada = 'recuperada';

  /// client_event_id (UUID v4): hace idempotente la sincronización.
  final String id;
  final String usuarioId;
  final DateTime fechaHoraIngreso;
  final DateTime? fechaHoraSalida;
  final DateTime ultimoLatido;
  final String? tipoCierre;
  final bool rechazado;
  final int syncAttempts;
  final String? lastError;

  LogUsoLocal({
    required this.id,
    required this.usuarioId,
    required DateTime fechaHoraIngreso,
    DateTime? fechaHoraSalida,
    required DateTime ultimoLatido,
    this.tipoCierre,
    this.rechazado = false,
    this.syncAttempts = 0,
    this.lastError,
  })  : fechaHoraIngreso = fechaHoraIngreso.toUtc(),
        fechaHoraSalida = fechaHoraSalida?.toUtc(),
        ultimoLatido = ultimoLatido.toUtc();

  factory LogUsoLocal.abrir({
    required String id,
    required String usuarioId,
    required DateTime ahora,
  }) =>
      LogUsoLocal(
        id: id,
        usuarioId: usuarioId,
        fechaHoraIngreso: ahora,
        ultimoLatido: ahora,
      );

  bool get abierta => fechaHoraSalida == null;

  bool get enSegundoPlano =>
      fechaHoraSalida != null && tipoCierre == cierreSegundoPlano;

  LogUsoLocal _con({
    DateTime? salida,
    bool limpiarSalida = false,
    DateTime? latido,
    String? tipo,
    bool limpiarTipo = false,
  }) =>
      LogUsoLocal(
        id: id,
        usuarioId: usuarioId,
        fechaHoraIngreso: fechaHoraIngreso,
        fechaHoraSalida: limpiarSalida ? null : (salida ?? fechaHoraSalida),
        ultimoLatido: latido ?? ultimoLatido,
        tipoCierre: limpiarTipo ? null : (tipo ?? tipoCierre),
        rechazado: rechazado,
        syncAttempts: syncAttempts,
        lastError: lastError,
      );

  LogUsoLocal cerrar(DateTime salida, String tipo) {
    // La salida nunca puede quedar antes del ingreso (p. ej. reloj ajustado).
    final s = salida.isBefore(fechaHoraIngreso) ? fechaHoraIngreso : salida;
    return _con(salida: s, latido: s, tipo: tipo);
  }

  LogUsoLocal reabrir(DateTime ahora) =>
      _con(limpiarSalida: true, limpiarTipo: true, latido: ahora);

  LogUsoLocal conLatido(DateTime ahora) => _con(latido: ahora);

  Map<String, Object?> toMap() => {
        'id': id,
        'usuario_id': usuarioId,
        'fecha_hora_ingreso_ms': fechaHoraIngreso.millisecondsSinceEpoch,
        'fecha_hora_salida_ms': fechaHoraSalida?.millisecondsSinceEpoch,
        'ultimo_latido_ms': ultimoLatido.millisecondsSinceEpoch,
        'tipo_cierre': tipoCierre,
        'rechazado': rechazado ? 1 : 0,
        'sync_attempts': syncAttempts,
        'last_error': lastError,
      };

  factory LogUsoLocal.fromMap(Map<String, Object?> map) {
    DateTime? fecha(Object? ms) => ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch((ms as num).toInt(), isUtc: true);
    return LogUsoLocal(
      id: map['id'].toString(),
      usuarioId: map['usuario_id'].toString(),
      fechaHoraIngreso: fecha(map['fecha_hora_ingreso_ms'])!,
      fechaHoraSalida: fecha(map['fecha_hora_salida_ms']),
      ultimoLatido: fecha(map['ultimo_latido_ms'])!,
      tipoCierre: map['tipo_cierre']?.toString(),
      rechazado: (map['rechazado'] as num?)?.toInt() == 1,
      syncAttempts: (map['sync_attempts'] as num?)?.toInt() ?? 0,
      lastError: map['last_error']?.toString(),
    );
  }

  /// Cuerpo de cada evento en `POST /api/v1/logs/uso/sync`.
  /// No incluye usuario_id: el servidor lo toma del JWT.
  Map<String, dynamic> toSyncPayload({String? plataforma, String? versionApp}) => {
        'client_event_id': id,
        'fecha_hora_ingreso': fechaHoraIngreso.toIso8601String(),
        'fecha_hora_salida': fechaHoraSalida?.toIso8601String(),
        'tipo_cierre': tipoCierre,
        if (plataforma != null) 'plataforma': plataforma,
        if (versionApp != null) 'version_app': versionApp,
      };
}
