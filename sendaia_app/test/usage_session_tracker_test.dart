import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rimai_app/application/ports/local_db_port.dart';
import 'package:rimai_app/application/ports/log_uso_port.dart';
import 'package:rimai_app/application/ports/sync_port.dart';
import 'package:rimai_app/application/services/usage_session_tracker.dart';
import 'package:rimai_app/application/usecases/sync_offline_usecase.dart';
import 'package:rimai_app/domain/entities/actividad_local.dart';
import 'package:rimai_app/domain/entities/log_uso_local.dart';
import 'package:rimai_app/domain/entities/reporte.dart';

/// Implementación en memoria con la misma semántica que SqliteDbRepository.
class LocalFalso implements ILogUsoLocalPort {
  final Map<String, LogUsoLocal> filas = {};

  @override
  Future<void> guardarSesionUso(LogUsoLocal sesion) async => filas[sesion.id] = sesion;

  @override
  Future<List<LogUsoLocal>> sesionesUsoAbiertasOEnPausa() async => filas.values
      .where((s) => !s.rechazado && (s.abierta || s.enSegundoPlano))
      .toList()
    ..sort((a, b) => b.fechaHoraIngreso.compareTo(a.fechaHoraIngreso));

  @override
  Future<List<LogUsoLocal>> sesionesUsoListasParaSync({
    required String usuarioId,
    required DateTime finGracia,
    int limite = 200,
  }) async =>
      filas.values
          .where((s) =>
              s.usuarioId == usuarioId &&
              !s.rechazado &&
              !s.abierta &&
              (!s.enSegundoPlano || !s.fechaHoraSalida!.isAfter(finGracia.toUtc())))
          .take(limite)
          .toList();

  @override
  Future<void> eliminarSesionesUso(List<String> ids) async => ids.forEach(filas.remove);

  @override
  Future<void> marcarSesionesUsoRechazadas(Map<String, String> motivos) async {
    motivos.forEach((id, motivo) {
      final s = filas[id]!;
      filas[id] = LogUsoLocal(
        id: s.id,
        usuarioId: s.usuarioId,
        fechaHoraIngreso: s.fechaHoraIngreso,
        fechaHoraSalida: s.fechaHoraSalida,
        ultimoLatido: s.ultimoLatido,
        tipoCierre: s.tipoCierre,
        rechazado: true,
        lastError: motivo,
      );
    });
  }

  @override
  Future<void> registrarFalloSyncUso(List<String> ids, String error) async {}
}

class RemotoFalso implements ILogUsoRemotePort {
  final List<List<LogUsoLocal>> envios = [];
  Map<String, String> rechazar = {};
  bool fallar = false;

  @override
  Future<ResultadoSyncUso> enviarSesionesUso(List<LogUsoLocal> sesiones) async {
    if (fallar) throw Exception('sin red');
    envios.add(sesiones);
    return ResultadoSyncUso(
      aceptados: sesiones.map((s) => s.id).where((id) => !rechazar.containsKey(id)).toList(),
      rechazados: {
        for (final s in sesiones)
          if (rechazar.containsKey(s.id)) s.id: rechazar[s.id]!,
      },
    );
  }
}

class _ActividadesVacias implements ILocalDbPort {
  @override
  Future<void> deleteActividades(List<String> ids) async {}
  @override
  Future<List<ActividadLocal>> getActividadesPendientes() async => [];
  @override
  Future<void> saveActividad(ActividadLocal actividad) async {}
}

class _SyncNoUsado implements ISyncPort {
  @override
  Future<ReporteAnalitico> fetchReporte(int patientId, DateTime inicio, DateTime fin) =>
      throw UnimplementedError();
  @override
  Future<List<String>> syncActividades(List<ActividadLocal> actividades) async => [];
}

const padre = UsuarioSesionUso(usuarioId: 'padre-1', rol: 'padre_tutor');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalFalso local;
  late DateTime ahora;
  late UsuarioSesionUso? usuario;
  late int sincronizaciones;
  late int contadorIds;

  UsageSessionTracker nuevoTracker() => UsageSessionTracker(
        local: local,
        usuarioActual: () async => usuario,
        sincronizar: () async => sincronizaciones++,
        reloj: () => ahora,
        generarId: () => 'sesion-${++contadorIds}',
        intervaloLatido: const Duration(hours: 1), // sin timers reales en tests
      );

  Future<void> evento(UsageSessionTracker t, AppLifecycleState estado) {
    t.didChangeAppLifecycleState(estado);
    return t.enReposo;
  }

  setUp(() {
    local = LocalFalso();
    ahora = DateTime.utc(2026, 3, 2, 15);
    usuario = padre;
    sincronizaciones = 0;
    contadorIds = 0;
  });

  test('al arrancar con sesión válida de padre abre un acceso', () async {
    final t = nuevoTracker();
    await t.iniciar();
    expect(local.filas, hasLength(1));
    expect(t.sesionActual!.abierta, isTrue);
    expect(t.sesionActual!.usuarioId, 'padre-1');
    t.dispose();
  });

  test('no registra a roles fuera de la muestra', () async {
    usuario = const UsuarioSesionUso(usuarioId: 't-1', rol: 'terapeuta');
    final t = nuevoTracker();
    await t.iniciar();
    await t.alIniciarSesion('admin-1', 'admin');
    expect(local.filas, isEmpty);
    t.dispose();
  });

  test('volver antes de 5 min continúa la MISMA sesión (no infla N)', () async {
    final t = nuevoTracker();
    await t.iniciar();
    await evento(t, AppLifecycleState.paused);
    expect(t.sesionActual!.tipoCierre, LogUsoLocal.cierreSegundoPlano);

    ahora = ahora.add(const Duration(minutes: 4, seconds: 59));
    await evento(t, AppLifecycleState.resumed);

    expect(local.filas, hasLength(1));
    expect(t.sesionActual!.id, 'sesion-1');
    expect(t.sesionActual!.abierta, isTrue);
    t.dispose();
  });

  test('volver después de 5 min cierra la sesión anterior y abre otra', () async {
    final t = nuevoTracker();
    await t.iniciar();
    final salida = ahora.add(const Duration(minutes: 12));
    ahora = salida;
    await evento(t, AppLifecycleState.paused);

    ahora = ahora.add(const Duration(minutes: 6));
    await evento(t, AppLifecycleState.resumed);

    expect(local.filas, hasLength(2));
    final anterior = local.filas['sesion-1']!;
    expect(anterior.fechaHoraSalida, salida);
    expect(anterior.tipoCierre, LogUsoLocal.cierreSegundoPlano);
    expect(t.sesionActual!.id, 'sesion-2');
    t.dispose();
  });

  test('inactive/hidden (barra de notificaciones) no cortan la sesión', () async {
    final t = nuevoTracker();
    await t.iniciar();
    await evento(t, AppLifecycleState.inactive);
    await evento(t, AppLifecycleState.hidden);
    expect(t.sesionActual!.abierta, isTrue);
    t.dispose();
  });

  test('app cerrada a la fuerza: al arrancar se cierra con el último latido', () async {
    final latido = ahora.subtract(const Duration(minutes: 30));
    local.filas['huerfana'] = LogUsoLocal(
      id: 'huerfana',
      usuarioId: 'padre-1',
      fechaHoraIngreso: latido.subtract(const Duration(minutes: 8)),
      ultimoLatido: latido,
    );

    final t = nuevoTracker();
    await t.iniciar();

    final recuperada = local.filas['huerfana']!;
    expect(recuperada.tipoCierre, LogUsoLocal.cierreRecuperada);
    expect(recuperada.fechaHoraSalida, latido);
    expect(t.sesionActual!.id, 'sesion-1');
    t.dispose();
  });

  test('reabrir la app dentro de la gracia tras matarla en segundo plano continúa', () async {
    local.filas['previa'] = LogUsoLocal(
      id: 'previa',
      usuarioId: 'padre-1',
      fechaHoraIngreso: ahora.subtract(const Duration(minutes: 10)),
      fechaHoraSalida: ahora.subtract(const Duration(minutes: 2)),
      ultimoLatido: ahora.subtract(const Duration(minutes: 2)),
      tipoCierre: LogUsoLocal.cierreSegundoPlano,
    );
    final t = nuevoTracker();
    await t.iniciar();
    expect(local.filas, hasLength(1));
    expect(t.sesionActual!.id, 'previa');
    expect(t.sesionActual!.abierta, isTrue);
    t.dispose();
  });

  test('logout cierra la sesión como logout y sincroniza antes de borrar el token', () async {
    final t = nuevoTracker();
    await t.iniciar();
    final antes = sincronizaciones;
    ahora = ahora.add(const Duration(minutes: 7));
    await t.alCerrarSesion();

    final cerrada = local.filas['sesion-1']!;
    expect(cerrada.tipoCierre, LogUsoLocal.cierreLogout);
    expect(cerrada.fechaHoraSalida, ahora);
    expect(t.sesionActual, isNull);
    expect(sincronizaciones, greaterThan(antes));
    t.dispose();
  });

  test('login de otro padre en el mismo celular cierra la sesión del anterior', () async {
    final t = nuevoTracker();
    await t.iniciar();
    await t.alIniciarSesion('padre-2', 'padre_tutor');
    expect(local.filas['sesion-1']!.tipoCierre, LogUsoLocal.cierreLogout);
    expect(t.sesionActual!.usuarioId, 'padre-2');
    t.dispose();
  });

  group('SyncOfflineUsecase.sincronizarLogsUso', () {
    late RemotoFalso remoto;

    SyncOfflineUsecase uc(String? usuarioId) => SyncOfflineUsecase(
          _ActividadesVacias(),
          _SyncNoUsado(),
          logUsoLocal: local,
          logUsoRemoto: remoto,
          usuarioActual: () async => usuarioId,
          reloj: () => ahora,
        );

    LogUsoLocal cerrada(String id, String usuarioId, String tipo, Duration haceSalida) =>
        LogUsoLocal(
          id: id,
          usuarioId: usuarioId,
          fechaHoraIngreso: ahora.subtract(haceSalida + const Duration(minutes: 10)),
          fechaHoraSalida: ahora.subtract(haceSalida),
          ultimoLatido: ahora.subtract(haceSalida),
          tipoCierre: tipo,
        );

    setUp(() => remoto = RemotoFalso());

    test('sube solo sesiones definitivas del usuario del token', () async {
      for (final s in [
        cerrada('mia-logout', 'padre-1', LogUsoLocal.cierreLogout, Duration.zero),
        cerrada('mia-pausa-vieja', 'padre-1', LogUsoLocal.cierreSegundoPlano, const Duration(minutes: 6)),
        cerrada('mia-en-gracia', 'padre-1', LogUsoLocal.cierreSegundoPlano, const Duration(minutes: 1)),
        cerrada('de-otro-padre', 'padre-2', LogUsoLocal.cierreLogout, Duration.zero),
      ]) {
        local.filas[s.id] = s;
      }

      await uc('padre-1').sincronizarLogsUso();

      expect(remoto.envios.single.map((s) => s.id).toSet(), {'mia-logout', 'mia-pausa-vieja'});
      expect(local.filas.keys.toSet(), {'mia-en-gracia', 'de-otro-padre'});
    });

    test('rechazadas se marcan y no se reintentan; sin red quedan en cola', () async {
      local.filas['mala'] = cerrada('mala', 'padre-1', LogUsoLocal.cierreLogout, Duration.zero);
      remoto.rechazar = {'mala': 'duracion_excede_12h'};
      await uc('padre-1').sincronizarLogsUso();
      expect(local.filas['mala']!.rechazado, isTrue);

      await uc('padre-1').sincronizarLogsUso();
      expect(remoto.envios, hasLength(1));

      local.filas['buena'] = cerrada('buena', 'padre-1', LogUsoLocal.cierreLogout, Duration.zero);
      remoto.fallar = true;
      await uc('padre-1').sincronizarLogsUso();
      expect(local.filas.containsKey('buena'), isTrue);
    });

    test('sin usuario autenticado no envía nada', () async {
      local.filas['x'] = cerrada('x', 'padre-1', LogUsoLocal.cierreLogout, Duration.zero);
      await uc(null).sincronizarLogsUso();
      expect(remoto.envios, isEmpty);
    });
  });

  test('payload de sync: UTC ISO y sin usuario_id', () {
    final s = LogUsoLocal(
      id: 'abc',
      usuarioId: 'padre-1',
      fechaHoraIngreso: DateTime.utc(2026, 3, 2, 15),
      fechaHoraSalida: DateTime.utc(2026, 3, 2, 15, 12, 30),
      ultimoLatido: DateTime.utc(2026, 3, 2, 15, 12, 30),
      tipoCierre: LogUsoLocal.cierreLogout,
    );
    final payload = s.toSyncPayload(plataforma: 'android');
    expect(payload['fecha_hora_ingreso'], '2026-03-02T15:00:00.000Z');
    expect(payload.containsKey('usuario_id'), isFalse);
    expect(LogUsoLocal.fromMap(s.toMap()).fechaHoraSalida, s.fechaHoraSalida);
  });
}
