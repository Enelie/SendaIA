import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

import 'package:rimai_app/adapters/output/sqlite_db_repository.dart';
import 'package:rimai_app/adapters/output/api_sync_repository.dart';
import 'package:rimai_app/adapters/output/api_log_uso_repository.dart';
import 'package:rimai_app/application/services/usage_session_tracker.dart';
import 'package:rimai_app/application/usecases/sync_offline_usecase.dart';
import 'package:rimai_app/core/constants/api_constants.dart';
import 'package:rimai_app/infrastructure/config/auth_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resuelve la URL del backend (emulador vs adb reverse) en paralelo con la BD
  final baseUrlFuture = ApiConstants.ensureBaseUrlResolved();

  // SQLite no está disponible en Chrome; en web solo se resuelve la API.
  if (!kIsWeb) {
    final localDb = SqliteDbRepository();
    await localDb.database;
    await baseUrlFuture;

    const authStorage = AuthStorageService(FlutterSecureStorage());
    final apiSyncRepo = ApiSyncRepository(
      baseUrl: ApiConstants.baseUrl,
      tokenProvider: authStorage.getToken,
    );

    // Registro de uso (Instrumento 3): docs/06_logs_y_metricas.md
    Future<UsuarioSesionUso?> usuarioSesionUso() async {
      final token = await authStorage.getToken();
      if (token == null) return null;
      try {
        if (JwtDecoder.isExpired(token)) return null;
      } catch (_) {
        return null;
      }
      final usuarioId = AuthStorageService.usuarioIdDelToken(token) ??
          await authStorage.getUserId();
      final rol = await authStorage.getRole();
      if (usuarioId == null || usuarioId.isEmpty || rol == null) return null;
      return UsuarioSesionUso(usuarioId: usuarioId, rol: rol);
    }

    final syncUsecase = SyncOfflineUsecase(
      localDb,
      apiSyncRepo,
      logUsoLocal: localDb,
      logUsoRemoto: ApiLogUsoRepository(
        baseUrl: ApiConstants.baseUrl,
        tokenProvider: authStorage.getToken,
        versionApp: await obtenerVersionApp(),
      ),
      usuarioActual: () async => (await usuarioSesionUso())?.usuarioId,
    );

    final usageTracker = UsageSessionTracker(
      local: localDb,
      usuarioActual: usuarioSesionUso,
      sincronizar: syncUsecase.sincronizarLogsUso,
    );
    AuthSessionHooks.alGuardarSesion = usageTracker.alIniciarSesion;
    AuthSessionHooks.antesDeLimpiarSesion = usageTracker.alCerrarSesion;
    usageTracker.iniciar();

    syncUsecase.execute();
    Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection =
          results.any((result) => result != ConnectivityResult.none);
      if (hasConnection) {
        syncUsecase.execute();
      }
    });
  } else {
    await baseUrlFuture;
  }

  runApp(
    const ProviderScope(
      child: RimAIApp(),
    ),
  );
}

class RimAIApp extends ConsumerWidget {
  const RimAIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'SENDAIA — Apoyo parental en el aprendizaje',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: PMV2Theme.theme,
    );
  }
}
