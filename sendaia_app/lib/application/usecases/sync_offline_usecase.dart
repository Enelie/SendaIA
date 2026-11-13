import '../../domain/entities/log_uso_local.dart';
import '../ports/local_db_port.dart';
import '../ports/log_uso_port.dart';
import '../ports/sync_port.dart';

class SyncOfflineUsecase {
  final ILocalDbPort localDbPort;
  final ISyncPort syncPort;

  // Registro de uso (Instrumento 3). Opcionales: sin ellos solo se
  // sincronizan las actividades, como antes.
  final ILogUsoLocalPort? logUsoLocal;
  final ILogUsoRemotePort? logUsoRemoto;

  /// usuario_id del token actual. Solo se suben SUS sesiones: el servidor
  /// atribuye cada evento al usuario del JWT, así que subir sesiones de otro
  /// padre que usó el mismo celular las asignaría a la persona equivocada.
  final Future<String?> Function()? usuarioActual;
  final DateTime Function() _reloj;

  static const int _tamanoLote = 200;
  bool _logsEnCurso = false;

  SyncOfflineUsecase(
    this.localDbPort,
    this.syncPort, {
    this.logUsoLocal,
    this.logUsoRemoto,
    this.usuarioActual,
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now;

  Future<void> execute() async {
    try {
      final pendientes = await localDbPort.getActividadesPendientes();

      if (pendientes.isNotEmpty) {
        final syncedIds = await syncPort.syncActividades(pendientes);
        if (syncedIds.isNotEmpty) {
          await localDbPort.deleteActividades(syncedIds);
        }
      }
    } finally {
      await sincronizarLogsUso();
    }
  }

  /// Sube las sesiones de uso cerradas de forma definitiva. Nunca lanza:
  /// lo que no se pudo subir queda en la cola local para el próximo intento.
  Future<void> sincronizarLogsUso() async {
    final local = logUsoLocal;
    final remoto = logUsoRemoto;
    final obtenerUsuario = usuarioActual;
    if (local == null || remoto == null || obtenerUsuario == null) return;
    if (_logsEnCurso) return;
    _logsEnCurso = true;

    try {
      final usuarioId = await obtenerUsuario();
      if (usuarioId == null || usuarioId.isEmpty) return;
      // Las sesiones en pausa dentro del período de gracia aún pueden reabrirse.
      final finGracia = _reloj().subtract(kPeriodoGraciaUso);

      while (true) {
        final lote = await local.sesionesUsoListasParaSync(
          usuarioId: usuarioId,
          finGracia: finGracia,
          limite: _tamanoLote,
        );
        if (lote.isEmpty) return;

        final ResultadoSyncUso resultado;
        try {
          resultado = await remoto.enviarSesionesUso(lote);
        } catch (e) {
          await local.registrarFalloSyncUso(lote.map((s) => s.id).toList(), e.toString());
          return;
        }

        await local.eliminarSesionesUso(resultado.aceptados);
        await local.marcarSesionesUsoRechazadas(resultado.rechazados);

        final resueltos = {...resultado.aceptados, ...resultado.rechazados.keys};
        final sinResolver =
            lote.map((s) => s.id).where((id) => !resueltos.contains(id)).toList();
        if (sinResolver.isNotEmpty) {
          await local.registrarFalloSyncUso(sinResolver, 'reintentar');
        }
        // Sin progreso o último lote: se termina para no girar en vacío.
        if (resueltos.isEmpty || lote.length < _tamanoLote) return;
      }
    } catch (_) {
      // El registro de uso nunca debe romper la sincronización de la app.
    } finally {
      _logsEnCurso = false;
    }
  }
}
