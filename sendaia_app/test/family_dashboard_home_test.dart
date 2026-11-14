import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rimai_app/adapters/input/screens/dashboard/familia_dashboard_screen.dart';
import 'package:rimai_app/core/providers/dashboard_providers.dart';
import 'package:rimai_app/core/providers/familia_sugerencias_providers.dart';
import 'package:rimai_app/core/providers/seguimiento_providers.dart';

class _FakeSeguimientoService extends SeguimientoService {
  _FakeSeguimientoService() : super(Dio());

  @override
  Future<SeguimientoFamiliar> obtener(
    String ninoId,
    DateTime desde,
    DateTime hasta,
  ) async {
    return SeguimientoFamiliar.fromJson({
      'nino_id': ninoId,
      'desde': desde.toIso8601String().substring(0, 10),
      'hasta': hasta.toIso8601String().substring(0, 10),
      'resumen': {'actividades_completadas': 1, 'dias_con_actividad': 1},
      'registros': [
        {
          'id': 'r1',
          'actividad_id': 'a1',
          'actividad_nombre': 'Lectura guiada',
          'fecha': DateTime.now().toIso8601String(),
          'estado': 'completada',
        }
      ],
      'por_semana': [],
      'recomendadas': [],
    });
  }
}

SugerenciasFamilia _sugerencias(String ninoId, String nombre) {
  return SugerenciasFamilia(
    ninoId: ninoId,
    ninoNombre: nombre,
    dificultadEstimada: 'Media',
    confianzaModelo: 0.8,
    perfilCompleto: true,
    camposPerfilUsados: const ['intereses'],
    sugerencias: const [
      SugerenciaActividad(
        actividadId: 'a2',
        nombre: 'Ordenar secuencias',
        tipo: 'Atención',
        nivelDificultad: 'Medio',
        duracionSegundos: 600,
        duracionMinutos: 10,
        instrucciones: 'Ordena las tarjetas.',
        materiales: [],
        puntuacion: 90,
        motivos: [],
        consejos: [],
      ),
    ],
    totalCatalogo: 10,
    nota: '',
  );
}

void main() {
  testWidgets('family home shows child summary and real dashboard sections',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final router = GoRouter(
      initialLocation: '/familia/dashboard',
      routes: [
        GoRoute(
          path: '/familia/dashboard',
          builder: (_, state) => FamiliaDashboardScreen(
            initialNinoId: state.uri.queryParameters['nino'],
          ),
        ),
        GoRoute(
          path: '/familia/perfil',
          builder: (_, state) => Text(
            'PROFILE_ROUTE ${state.uri.queryParameters['nino']}',
          ),
        ),
        GoRoute(
          path: '/familia/seguimiento',
          builder: (_, state) => Text(
            'TRACKING_ROUTE ${state.uri.queryParameters['nino']}',
          ),
        ),
        GoRoute(
          path: '/familia/sugerencias',
          builder: (_, state) => Text(
            'SUGGESTIONS_ROUTE ${state.uri.queryParameters['ninoId']}',
          ),
        ),
        GoRoute(
          path: '/familia/chatbot',
          builder: (_, state) => Text(
            'CHATBOT_ROUTE ${state.uri.queryParameters['nino']}',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          familiaDashboardProvider.overrideWith(
            (ref) async => DashboardData.fromJson({
              'total_pacientes': 1,
              'sesiones_esta_semana': 2,
              'alertas_baja_adherencia': 0,
              'pacientes': [
                {
                  'id': 'nino-1',
                  'nombre': 'Sofía',
                  'edad': 7,
                  'nivel_cognitivo': 'Medio',
                  'diagnostico': 'TDAH',
                  'intereses': ['Dinosaurios'],
                  'hitos': {
                    'forma_aprende': ['Visual'],
                  },
                },
                {
                  'id': 'nino-2',
                  'nombre': 'Diego',
                  'edad': 9,
                  'nivel_cognitivo': 'Alto',
                },
              ],
            }),
          ),
          notificacionesProvider.overrideWith(
            (ref) async => <NotificacionData>[],
          ),
          seguimientoServiceProvider.overrideWith(
            (ref) => _FakeSeguimientoService(),
          ),
          sugerenciasFamiliaProvider.overrideWith(
            (ref, ninoId) async => _sugerencias(
              ninoId,
              ninoId == 'nino-2' ? 'Diego' : 'Sofía',
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Niño seleccionado'), findsOneWidget);
    expect(find.text('Sofía'), findsWidgets);
    expect(find.text('Forma de aprender'), findsOneWidget);
    expect(find.text('Nivel de aprendizaje'), findsOneWidget);
    expect(find.text('Dinosaurios'), findsOneWidget);
    expect(find.text('Actividades recomendadas por IA'), findsOneWidget);
    expect(find.text('Ordenar secuencias'), findsOneWidget);
    expect(find.text('Actividad en casa'), findsOneWidget);
    expect(find.text('Lectura guiada'), findsOneWidget);
    expect(find.text('Asistente para padres'), findsOneWidget);

    // Los accesos rápidos duplicados ya no están en Inicio.
    expect(find.text('Perfil de aprendizaje'), findsNothing);
    expect(find.text('Seguimiento familiar'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diego').last);
    await tester.pumpAndSettle();
    expect(find.text('Diego'), findsWidgets);

    final suggestionsAccess = find.text('Ver todas las sugerencias');
    await tester.ensureVisible(suggestionsAccess);
    await tester.pumpAndSettle();
    await tester.tap(suggestionsAccess);
    await tester.pumpAndSettle();
    expect(find.text('SUGGESTIONS_ROUTE nino-2'), findsOneWidget);

    router.go('/familia/dashboard?nino=nino-2');
    await tester.pumpAndSettle();
    final assistantAccess = find.text('Hablar con el asistente');
    await tester.ensureVisible(assistantAccess);
    await tester.pumpAndSettle();
    await tester.tap(assistantAccess);
    await tester.pumpAndSettle();
    expect(find.text('CHATBOT_ROUTE nino-2'), findsOneWidget);

    router.go('/familia/dashboard?nino=nino-2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seguimiento'));
    await tester.pumpAndSettle();
    expect(find.text('TRACKING_ROUTE nino-1'), findsNothing);
    expect(find.text('TRACKING_ROUTE nino-2'), findsOneWidget);
  });

  testWidgets(
      'family home opens the registration wizard when there are no children',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final router = GoRouter(
      initialLocation: '/familia/dashboard',
      routes: [
        GoRoute(
          path: '/familia/dashboard',
          builder: (_, state) => FamiliaDashboardScreen(
            initialNinoId: state.uri.queryParameters['nino'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          familiaDashboardProvider.overrideWith(
            (ref) async => DashboardData.fromJson({
              'total_pacientes': 0,
              'sesiones_esta_semana': 0,
              'alertas_baja_adherencia': 0,
              'pacientes': <Map<String, dynamic>>[],
            }),
          ),
          notificacionesProvider.overrideWith(
            (ref) async => <NotificacionData>[],
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Paso 1/4'), findsOneWidget);
    expect(find.text('Datos básicos'), findsOneWidget);
    expect(find.text('NOMBRE DEL NIÑO'), findsOneWidget);
  });

  testWidgets('family home adapts without overflow to small and large screens',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in <double>[360, 1440]) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 900);

      final router = GoRouter(
        initialLocation: '/familia/dashboard',
        routes: [
          GoRoute(
            path: '/familia/dashboard',
            builder: (_, state) => FamiliaDashboardScreen(
              initialNinoId: state.uri.queryParameters['nino'],
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            familiaDashboardProvider.overrideWith(
              (ref) async => DashboardData.fromJson({
                'total_pacientes': 1,
                'sesiones_esta_semana': 1,
                'alertas_baja_adherencia': 0,
                'pacientes': [
                  {
                    'id': 'nino-1',
                    'nombre': 'Sofía',
                    'edad': 7,
                    'nivel_cognitivo': 'Medio',
                    'intereses': ['Dinosaurios'],
                    'hitos': {
                      'forma_aprende': ['Visual'],
                    },
                  },
                ],
              }),
            ),
            notificacionesProvider.overrideWith(
              (ref) async => <NotificacionData>[],
            ),
            seguimientoServiceProvider.overrideWith(
              (ref) => _FakeSeguimientoService(),
            ),
            sugerenciasFamiliaProvider.overrideWith(
              (ref, ninoId) async => _sugerencias(ninoId, 'Sofía'),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Actividades recomendadas por IA'), findsOneWidget);
      expect(find.text('Actividad en casa'), findsOneWidget);
      expect(find.text('Asistente para padres'), findsOneWidget);
    }
  });
}
