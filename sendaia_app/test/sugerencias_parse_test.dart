import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rimai_app/core/providers/dashboard_providers.dart';
import 'package:rimai_app/core/providers/familia_sugerencias_providers.dart';

void main() {
  test('sugerencias se parsean desde la API real', () async {
    final dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:8000',
      headers: {'Content-Type': 'application/json'},
      responseType: ResponseType.json,
    ));
    try {
      final login = await dio.post('/api/v1/auth/login', data: {
        'email': 'familia1@rimai.dev',
        'password': 'Rimai2024!',
      });
      final token = (login.data as Map)['access_token'];
      dio.interceptors.add(
        InterceptorsWrapper(onRequest: (options, handler) {
          options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        }),
      );

      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);

      final datos = await container.read(
        sugerenciasFamiliaProvider('cccccccc-0000-0000-0000-000000000001')
            .future,
      );
      // ignore: avoid_print
      print('OK: ${datos.ninoNombre} ${datos.dificultadEstimada} '
          '${datos.sugerencias.map((s) => s.nombre).toList()}');
      expect(datos.sugerencias, isNotEmpty);
    } on DioException {
      markTestSkipped('Backend local no disponible; prueba omitida.');
    }
  });
}
