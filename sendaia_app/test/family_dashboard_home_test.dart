import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rimai_app/adapters/input/screens/dashboard/familia_dashboard_screen.dart';
import 'package:rimai_app/core/providers/dashboard_providers.dart';
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
      'resumen': {'actividades_completadas': 1},
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

void main() {
  testWidgets('family home centers on selected child and quick links',
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
          path: '/familia/plan/:ninoId',
          builder: (_, state) => Text(
            'ACTIVITIES_ROUTE ${state.pathParameters['ninoId']}',
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
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Niño seleccionado'), findsOneWidget);
    expect(find.text('Sofía'), findsWidgets);
    expect(find.text('Resumen de su perfil'), findsOneWidget);
    expect(find.text('Nivel de aprendizaje'), findsOneWidget);
    expect(find.text('Dinosaurios'), findsOneWidget);
    expect(find.text('ACTIVIDAD RECIENTE'), findsOneWidget);
    expect(find.text('Lectura guiada'), findsOneWidget);
    expect(find.text('Perfil de aprendizaje'), findsOneWidget);
    expect(find.text('Sugerencias de actividades'), findsOneWidget);
    expect(find.text('Seguimiento familiar'), findsOneWidget);
    expect(find.text('Asistente para padres'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diego').last);
    await tester.pumpAndSettle();
    expect(find.text('Diego'), findsWidgets);

    final activitiesAccess = find.text('Sugerencias de actividades');
    await tester.ensureVisible(activitiesAccess);
    await tester.pumpAndSettle();
    await tester.tap(activitiesAccess);
    await tester.pumpAndSettle();
    expect(find.text('ACTIVITIES_ROUTE nino-2'), findsOneWidget);

    router.go('/familia/dashboard?nino=nino-2');
    await tester.pumpAndSettle();
    final assistantAccess = find.text('Asistente para padres');
    await tester.ensureVisible(assistantAccess);
    await tester.pumpAndSettle();
    await tester.tap(assistantAccess);
    await tester.pumpAndSettle();
    expect(find.text('CHATBOT_ROUTE nino-2'), findsOneWidget);

    router.go('/familia/dashboard?nino=nino-2');
    await tester.pumpAndSettle();
    final trackingAccess = find.text('Seguimiento familiar');
    await tester.ensureVisible(trackingAccess);
    await tester.pumpAndSettle();
    await tester.tap(trackingAccess);
    await tester.pumpAndSettle();

    expect(find.text('TRACKING_ROUTE nino-1'), findsNothing);
    expect(find.text('TRACKING_ROUTE nino-2'), findsOneWidget);
  });
}
