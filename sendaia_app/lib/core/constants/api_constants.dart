import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiConstants {
  /// Override manual, p. ej. para probar contra la IP de la PC en la misma Wi-Fi:
  /// `flutter run --dart-define=API_BASE=http://192.168.1.40:8000`
  static const String overrideBaseUrl = String.fromEnvironment('API_BASE');

  /// URLs locales candidatas, en orden de preferencia. Al arrancar se prueba
  /// `GET /health` contra cada una y se queda la primera que responda:
  ///
  /// - `10.0.2.2`: host de la PC tal como lo ve el emulador Android.
  /// - `localhost`: funciona con `adb reverse tcp:8000 tcp:8000`, con el
  ///   simulador de iOS y en escritorio.
  static const List<String> candidateBaseUrls = <String>[
    'http://10.0.2.2:8000',
    'http://localhost:8000',
  ];

  static String? _resolvedBaseUrl;
  static Future<void>? _resolution;

  /// URL efectiva del backend. Si aún no se resolvió, devuelve el primer
  /// candidato, que es el correcto para el emulador Android.
  static String get baseUrl => overrideBaseUrl.isNotEmpty
      ? overrideBaseUrl
      : _resolvedBaseUrl ?? candidateBaseUrls.first;

  /// Resuelve [baseUrl]. Se puede llamar en cada request: solo hace el sondeo
  /// una vez. Si el backend está apagado no recuerda el fallo, el siguiente
  /// intento vuelve a probar.
  static Future<void> ensureBaseUrlResolved() {
    if (overrideBaseUrl.isNotEmpty) return Future<void>.value();
    return _resolution ??= _resolve();
  }

  static Future<void> _resolve() async {
    final probe = Dio(BaseOptions(
      connectTimeout: const Duration(milliseconds: 900),
      receiveTimeout: const Duration(milliseconds: 900),
    ));

    for (final url in candidateBaseUrls) {
      try {
        final res = await probe.get<dynamic>('$url/health');
        final code = res.statusCode;
        if (code != null && code < 500) {
          _resolvedBaseUrl = url;
          debugPrint('ApiConstants: backend en $url');
          return;
        }
      } catch (_) {
        // Candidato no disponible: probamos el siguiente.
      }
    }

    // Ninguno respondió: no cachear el fallo para reintentar más adelante.
    debugPrint(
        'ApiConstants: ningún candidato responde, se usa ${candidateBaseUrls.first}');
    _resolution = null;
  }
}
