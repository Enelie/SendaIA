import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/log_uso_local.dart';
import '../ports/log_uso_port.dart';

/// Usuario autenticado actual según el token guardado (null si no hay sesión
/// válida).
class UsuarioSesionUso {
  final String usuarioId;
  final String rol;

  const UsuarioSesionUso({required this.usuarioId, required this.rol});

  bool get registrable => kRolesRegistradosUso.contains(rol);
}

typedef ObtenerUsuarioSesionUso = Future<UsuarioSesionUso?> Function();

/// Registra las sesiones de uso del aplicativo (Instrumento 3: FU y TPP).
///
/// Reglas (docs/06_logs_y_metricas.md):
/// * Ingreso: login exitoso, o abrir/volver a la app con un token válido.
/// * Pasar a segundo plano cierra la sesión de forma provisional; si el padre
///   vuelve dentro de [kPeriodoGraciaUso] se reabre la MISMA sesión.
/// * Logout cierra la sesión con tipo `logout`.
/// * Si la app murió con la sesión abierta, al arrancar se cierra con
///   salida = último latido y tipo `recuperada`.
/// * Solo se registra a padres/tutores.
class UsageSessionTracker with WidgetsBindingObserver {
  final ILogUsoLocalPort _local;
  final ObtenerUsuarioSesionUso _usuarioActual;
  final Future<void> Function()? _sincronizar;
  final DateTime Function() _reloj;
  final String Function() _generarId;
  final Duration _intervaloLatido;

  LogUsoLocal? _actual;
  Timer? _latido;
  Future<void> _cola = Future<void>.value();
  bool _iniciado = false;

  UsageSessionTracker({
    required ILogUsoLocalPort local,
    required ObtenerUsuarioSesionUso usuarioActual,
    Future<void> Function()? sincronizar,
    DateTime Function()? reloj,
    String Function()? generarId,
    Duration intervaloLatido = kIntervaloLatidoUso,
  })  : _local = local,
        _usuarioActual = usuarioActual,
        _sincronizar = sincronizar,
        _reloj = reloj ?? DateTime.now,
        _generarId = generarId ?? (() => const Uuid().v4()),
        _intervaloLatido = intervaloLatido;

  /// Sesión en curso (abierta o en pausa dentro del período de gracia).
  LogUsoLocal? get sesionActual => _actual;

  /// Se completa cuando terminan las operaciones encoladas (útil en tests).
  Future<void> get enReposo => _cola;

  /// Ejecuta [op] después de las operaciones anteriores. Un fallo del
  /// registro de uso nunca debe romper la app.
  Future<void> _enSerie(Future<void> Function() op) {
    _cola = _cola.then((_) => op()).catchError((Object e, StackTrace st) {
      debugPrint('UsageSessionTracker: $e');
    });
    return _cola;
  }

  void _sincronizarEnSegundoPlano() {
    final sync = _sincronizar;
    if (sync == null) return;
    unawaited(sync().catchError((Object e) {
      debugPrint('UsageSessionTracker sync: $e');
    }));
  }

  // ---------------------------------------------------------------------------
  // Ciclo de vida
  // ---------------------------------------------------------------------------

  /// Llamar una vez al arrancar la app.
  Future<void> iniciar() {
    if (!_iniciado) {
      _iniciado = true;
      WidgetsBinding.instance.addObserver(this);
    }
    return _enSerie(_recuperarYAbrir);
  }

  void dispose() {
    if (_iniciado) WidgetsBinding.instance.removeObserver(this);
    _iniciado = false;
    _detenerLatido();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _enSerie(_pausar);
        break;
      case AppLifecycleState.resumed:
        _enSerie(_reanudar);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Transitorios (p. ej. bajar la barra de notificaciones): no cortan la sesión.
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Ganchos de autenticación
  // ---------------------------------------------------------------------------

  Future<void> alIniciarSesion(String usuarioId, String rol) {
    return _enSerie(() async {
      final actual = _actual;
      if (actual != null && actual.abierta && actual.usuarioId == usuarioId) {
        return;
      }
      if (actual != null && actual.abierta) {
        // Otro usuario en el mismo dispositivo: se cierra la sesión anterior.
        await _local.guardarSesionUso(
            actual.cerrar(_reloj(), LogUsoLocal.cierreLogout));
      }
      _actual = null;
      _detenerLatido();
      if (kRolesRegistradosUso.contains(rol)) {
        await _abrirNueva(usuarioId);
      }
      _sincronizarEnSegundoPlano();
    });
  }

  /// Se llama ANTES de borrar el token, para poder subir la sesión recién
  /// cerrada con las credenciales de su dueño.
  Future<void> alCerrarSesion() async {
    await _enSerie(() async {
      final actual = _actual;
      if (actual != null && actual.abierta) {
        await _local.guardarSesionUso(
            actual.cerrar(_reloj(), LogUsoLocal.cierreLogout));
      }
      _actual = null;
      _detenerLatido();
    });
    final sync = _sincronizar;
    if (sync != null) {
      try {
        await sync().timeout(const Duration(seconds: 5));
      } catch (e) {
        // Sin red: queda en la cola y se sube en el próximo login del mismo usuario.
        debugPrint('UsageSessionTracker logout sync: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Transiciones
  // ---------------------------------------------------------------------------

  bool _dentroDeGracia(DateTime referencia, DateTime ahora) =>
      ahora.toUtc().difference(referencia) <= kPeriodoGraciaUso;

  Future<void> _recuperarYAbrir() async {
    final ahora = _reloj();
    final usuario = await _usuarioActual();
    final pendientes = await _local.sesionesUsoAbiertasOEnPausa();

    LogUsoLocal? continuar;
    for (final s in pendientes) {
      final referencia = s.fechaHoraSalida ?? s.ultimoLatido;
      final esDelUsuario = usuario != null &&
          usuario.registrable &&
          s.usuarioId == usuario.usuarioId;
      if (continuar == null && esDelUsuario && _dentroDeGracia(referencia, ahora)) {
        continuar = s;
        continue;
      }
      if (s.abierta) {
        // La app murió en primer plano: salida = último latido conocido.
        await _local.guardarSesionUso(
            s.cerrar(s.ultimoLatido, LogUsoLocal.cierreRecuperada));
      }
      // En pausa y fuera de gracia: ya es definitiva, se sube en el próximo sync.
    }

    if (continuar != null) {
      _actual = continuar.reabrir(ahora);
      await _local.guardarSesionUso(_actual!);
      _iniciarLatido();
    } else if (usuario != null && usuario.registrable) {
      await _abrirNueva(usuario.usuarioId);
    }
    _sincronizarEnSegundoPlano();
  }

  Future<void> _abrirNueva(String usuarioId) async {
    final sesion = LogUsoLocal.abrir(
      id: _generarId(),
      usuarioId: usuarioId,
      ahora: _reloj(),
    );
    await _local.guardarSesionUso(sesion);
    _actual = sesion;
    _iniciarLatido();
  }

  Future<void> _pausar() async {
    final actual = _actual;
    _detenerLatido();
    if (actual == null || !actual.abierta) return;
    _actual = actual.cerrar(_reloj(), LogUsoLocal.cierreSegundoPlano);
    await _local.guardarSesionUso(_actual!);
  }

  Future<void> _reanudar() async {
    final ahora = _reloj();
    final actual = _actual;
    if (actual != null && actual.abierta) {
      _iniciarLatido();
      return;
    }

    final usuario = await _usuarioActual();
    if (actual != null &&
        actual.enSegundoPlano &&
        usuario != null &&
        usuario.usuarioId == actual.usuarioId &&
        _dentroDeGracia(actual.fechaHoraSalida!, ahora)) {
      // Interrupción breve: misma sesión.
      _actual = actual.reabrir(ahora);
      await _local.guardarSesionUso(_actual!);
      _iniciarLatido();
      return;
    }

    // La sesión anterior (si la hay) queda cerrada en su salida provisional.
    _actual = null;
    if (usuario != null && usuario.registrable) {
      await _abrirNueva(usuario.usuarioId);
    }
    _sincronizarEnSegundoPlano();
  }

  void _iniciarLatido() {
    _detenerLatido();
    _latido = Timer.periodic(_intervaloLatido, (_) {
      _enSerie(() async {
        final actual = _actual;
        if (actual == null || !actual.abierta) return;
        _actual = actual.conLatido(_reloj());
        await _local.guardarSesionUso(_actual!);
      });
    });
  }

  void _detenerLatido() {
    _latido?.cancel();
    _latido = null;
  }
}
