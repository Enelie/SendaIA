import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rimai_app/adapters/output/api_log_uso_repository.dart';
import 'package:rimai_app/domain/entities/log_uso_local.dart';

LogUsoLocal _sesion(String id) => LogUsoLocal(
      id: id,
      usuarioId: 'padre-1',
      fechaHoraIngreso: DateTime.utc(2026, 3, 2, 15),
      fechaHoraSalida: DateTime.utc(2026, 3, 2, 15, 10),
      ultimoLatido: DateTime.utc(2026, 3, 2, 15, 10),
      tipoCierre: LogUsoLocal.cierreLogout,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('version_app', () {
    test('se obtiene de package_info_plus como version+build', () async {
      PackageInfo.setMockInitialValues(
        appName: 'SENDAIA',
        packageName: 'pe.sendaia.app',
        version: '2.3.0',
        buildNumber: '1',
        buildSignature: '',
      );
      expect(await obtenerVersionApp(), '2.3.0+1');
    });

    test('sin build number queda solo la versión; vacía es null', () {
      expect(formatearVersionApp('2.3.0', ''), '2.3.0');
      expect(formatearVersionApp('  ', '7'), isNull);
    });

    test('se trunca a 20 caracteres para no hacer fallar el lote', () {
      final v = formatearVersionApp('10.20.30-beta.12345', '9999');
      expect(v!.length, kMaxLongitudVersionApp);
    });
  });

  test('envía version_app, plataforma y token; nunca usuario_id', () async {
    late Map<String, dynamic> cuerpo;
    late http.Request peticion;
    final client = MockClient((request) async {
      peticion = request;
      cuerpo = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'aceptados': ['a'],
          'rechazados': [
            {'client_event_id': 'b', 'motivo': 'duracion_excede_12h'}
          ],
          'reintentar': [],
        }),
        200,
      );
    });

    final repo = ApiLogUsoRepository(
      baseUrl: 'http://api.test',
      tokenProvider: () async => 'jwt-123',
      client: client,
      versionApp: '2.3.0+1',
    );
    final resultado = await repo.enviarSesionesUso([_sesion('a'), _sesion('b')]);

    expect(peticion.url.toString(), 'http://api.test/api/v1/logs/uso/sync');
    expect(peticion.headers['Authorization'], 'Bearer jwt-123');
    final eventos = (cuerpo['eventos'] as List).cast<Map<String, dynamic>>();
    expect(eventos, hasLength(2));
    expect(eventos.first['version_app'], '2.3.0+1');
    expect(eventos.first['plataforma'], isNotEmpty);
    expect(eventos.first.containsKey('usuario_id'), isFalse);
    expect(resultado.aceptados, ['a']);
    expect(resultado.rechazados, {'b': 'duracion_excede_12h'});
  });

  test('un error HTTP lanza excepción para que la sesión quede en cola', () async {
    final repo = ApiLogUsoRepository(
      baseUrl: 'http://api.test',
      tokenProvider: () async => 'jwt-123',
      client: MockClient((_) async => http.Response('error', 503)),
    );
    expect(() => repo.enviarSesionesUso([_sesion('a')]), throwsA(isA<http.ClientException>()));
  });

  test('sin token no envía nada', () async {
    var llamadas = 0;
    final repo = ApiLogUsoRepository(
      baseUrl: 'http://api.test',
      tokenProvider: () async => null,
      client: MockClient((_) async {
        llamadas++;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(repo.enviarSesionesUso([_sesion('a')]), throwsStateError);
    expect(llamadas, 0);
  });
}
