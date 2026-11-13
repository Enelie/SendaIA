import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../application/ports/log_uso_port.dart';
import '../../domain/entities/log_uso_local.dart';

typedef LogUsoTokenProvider = Future<String?> Function();

/// Límite de `logs_uso.version_app` (VARCHAR(20)). Un valor más largo haría
/// que el servidor rechazara el lote completo con 422.
const int kMaxLongitudVersionApp = 20;

/// "version+build" de pubspec.yaml (p. ej. "2.3.0+1"), para diagnóstico de
/// incidencias. Null si la plataforma no puede informarla.
Future<String?> obtenerVersionApp() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return formatearVersionApp(info.version, info.buildNumber);
  } catch (_) {
    return null;
  }
}

String? formatearVersionApp(String version, String buildNumber) {
  final v = version.trim();
  if (v.isEmpty) return null;
  final b = buildNumber.trim();
  final completa = b.isEmpty ? v : '$v+$b';
  return completa.length > kMaxLongitudVersionApp
      ? completa.substring(0, kMaxLongitudVersionApp)
      : completa;
}

/// Sube sesiones de uso a `POST /api/v1/logs/uso/sync`.
class ApiLogUsoRepository implements ILogUsoRemotePort {
  final String baseUrl;
  final LogUsoTokenProvider tokenProvider;
  final http.Client _client;
  final String? versionApp;

  ApiLogUsoRepository({
    required this.baseUrl,
    required this.tokenProvider,
    http.Client? client,
    this.versionApp,
  }) : _client = client ?? http.Client();

  @override
  Future<ResultadoSyncUso> enviarSesionesUso(List<LogUsoLocal> sesiones) async {
    if (sesiones.isEmpty) {
      return const ResultadoSyncUso(aceptados: [], rechazados: {});
    }
    final token = await tokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw StateError('Sin sesión autenticada para sincronizar logs de uso');
    }

    final plataforma = kIsWeb ? 'web' : defaultTargetPlatform.name;
    final response = await _client
        .post(
          Uri.parse('$baseUrl/api/v1/logs/uso/sync'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'eventos': sesiones
                .map((s) => s.toSyncPayload(
                      plataforma: plataforma,
                      versionApp: versionApp,
                    ))
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
          'logs/uso/sync respondió ${response.statusCode}', response.request?.url);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final aceptados = (body['aceptados'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final rechazados = <String, String>{
      for (final r in (body['rechazados'] as List? ?? const []))
        if (r is Map)
          r['client_event_id'].toString(): r['motivo']?.toString() ?? 'rechazado',
    };
    return ResultadoSyncUso(aceptados: aceptados, rechazados: rechazados);
  }
}
