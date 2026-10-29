import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rimai_app/adapters/input/screens/familia/family_tracking_screen.dart';
import 'package:rimai_app/adapters/output/sqlite_db_repository.dart';
import 'package:rimai_app/core/providers/dashboard_providers.dart';
import 'package:rimai_app/core/providers/pmv2_providers.dart';
import 'package:rimai_app/core/providers/seguimiento_providers.dart';
import 'package:rimai_app/domain/entities/actividad_local.dart';

class _FakeDashboard extends DashboardService {
  _FakeDashboard(this.ninos) : super(Dio());
  final List<Map<String, dynamic>> ninos;

  @override
  Future<DashboardData> obtenerResumenFamilia() async => DashboardData.fromJson({
        'total_pacientes': ninos.length,
        'sesiones_esta_semana': 0,
        'alertas_baja_adherencia': 0,
        'pacientes': ninos,
      });
}

class _FakeSeguimiento extends SeguimientoService {
  _FakeSeguimiento(this.respuestas, {this.fallos = 0}) : super(Dio());
  final Map<String, Map<String, dynamic>> respuestas;
  int fallos;
  final List<SeguimientoArgs> llamadas = [];

  @override
  Future<SeguimientoFamiliar> obtener(
      String ninoId, DateTime desde, DateTime hasta) async {
    llamadas.add((ninoId: ninoId, desde: desde, hasta: hasta));
    if (fallos > 0) {
      fallos--;
      throw Exception('No se pudo cargar el seguimiento. Revisa tu conexión.');
    }
    return SeguimientoFamiliar.fromJson({
      'nino_id': ninoId,
      'desde': desde.toIso8601String().substring(0, 10),
      'hasta': hasta.toIso8601String().substring(0, 10),
      ...respuestas[ninoId] ?? _vacio(),
    });
  }
}

class _FakeLocalDb extends SqliteDbRepository {
  _FakeLocalDb(this.pendientes);
  final List<ActividadLocal> pendientes;

  @override
  Future<List<ActividadLocal>> getActividadesPendientes() async => pendientes;
}

Map<String, dynamic> _vacio() => {
      'resumen': {
        'actividades_completadas': 0,
        'dias_con_actividad': 0,
        'segundos_totales': null,
        'registros_con_duracion': 0,
        'aciertos': 0,
        'intentos': 0,
      },
      'por_semana': [],
      'registros': [],
      'registros_truncados': false,
      'recomendadas': [],
    };

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _conDatos() {
  final hoy = DateTime.now();
  final lunes = DateTime(hoy.year, hoy.month, hoy.day - (hoy.weekday - 1));
  return {
    'resumen': {
      'actividades_completadas': 2,
      'dias_con_actividad': 2,
      'segundos_totales': 420.0,
      'registros_con_duracion': 1,
      'aciertos': 12,
      'intentos': 15,
    },
    'por_semana': [
      {
        'semana': lunes.toIso8601String().substring(0, 10),
        'actividades': 2,
        'segundos': 420.0
      }
    ],
    'registros': [
      {
        'id': 'r1',
        'actividad_id': 'a1',
        'actividad_nombre': 'Lectura guiada',
        'actividad_tipo': 'Lectura',
        'fecha': _iso(hoy.subtract(const Duration(hours: 2))),
        'estado': 'completada',
        'duracion_segundos': 420.0,
        'duracion_estimada_segundos': 600,
        'aciertos': 4,
        'intentos': 5,
        'nivel_ayuda_requerido': 1,
        'observaciones': 'Se concentró mejor con temporizador',
      },
      {
        'id': 'r2',
        'actividad_id': 'a3',
        'actividad_nombre': 'Contacto visual 5 seg',
        'fecha': _iso(hoy.subtract(const Duration(days: 1))),
        'estado': 'completada',
        'duracion_segundos': null, // registro legacy: sin duración real
        'aciertos': 8,
        'intentos': 10,
        'nivel_ayuda_requerido': 0,
        'observaciones': null,
      },
    ],
    'registros_truncados': false,
    'recomendadas': [
      {
        'plan_id': 'p1',
        'actividad_id': 'a1',
        'nombre': 'Lectura guiada',
        'realizada': true,
        'ultima_realizacion': _iso(hoy),
      },
      {
        'plan_id': 'p1',
        'actividad_id': 'a2',
        'nombre': 'Insertar piezas',
        'realizada': false,
        'ultima_realizacion': null,
      },
    ],
  };
}

final _diego = {'id': 'n1', 'nombre': 'Diego Vega', 'edad': 8};
final _valeria = {'id': 'n2', 'nombre': 'Valeria Vega', 'edad': 9};

ActividadLocal _pendiente(String ninoId) => ActividadLocal(
      id: 'local-$ninoId',
      ninoId: ninoId,
      planId: 'p1',
      actividadId: 'a2',
      aciertos: 1,
      repeticiones: 2,
      tiempoRespuestaSegundos: 60,
      nivelAyudaRequerido: 0,
      nivelDificultadUsado: 'Medio',
      timestampLocal: DateTime.now(),
    );

Future<_FakeSeguimiento> _pump(
  WidgetTester tester, {
  List<Map<String, dynamic>>? ninos,
  Map<String, Map<String, dynamic>> respuestas = const {},
  List<ActividadLocal> pendientes = const [],
  int fallos = 0,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final seguimiento = _FakeSeguimiento(respuestas, fallos: fallos);
  final router = GoRouter(
    initialLocation: '/familia/seguimiento',
    routes: [
      GoRoute(
          path: '/familia/seguimiento',
          builder: (_, __) => const FamilyTrackingScreen()),
      GoRoute(
          path: '/familia/plan/:id',
          builder: (_, s) => Text('PLAN ${s.pathParameters['id']}')),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dashboardServiceProvider
          .overrideWithValue(_FakeDashboard(ninos ?? [_diego])),
      seguimientoServiceProvider.overrideWithValue(seguimiento),
      sqliteDbRepositoryProvider.overrideWithValue(_FakeLocalDb(pendientes)),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return seguimiento;
}

DateTime _hoy() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('carga el historial con los datos guardados', (tester) async {
    final s = await _pump(tester, respuestas: {'n1': _conDatos()});

    expect(s.llamadas.single.ninoId, 'n1');
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('Actividades realizadas'), findsOneWidget);
    expect(find.text('12 de 15'), findsOneWidget);
    expect(find.text('7 min'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Historial de actividades'), 200);
    expect(find.text('Lectura guiada'), findsNWidgets(2)); // historial + plan
    expect(find.text('Duración: 7 min (estimada 10 min)'), findsOneWidget);
    expect(find.text('Resultado: 4 de 5 intentos correctos'), findsOneWidget);
    expect(find.text('Ayuda verbal'), findsOneWidget);
    expect(find.textContaining('temporizador'), findsOneWidget);
    // Registro legacy: se muestra el resultado pero no una duración inventada.
    expect(find.text('Resultado: 8 de 10 intentos correctos'), findsOneWidget);
    expect(find.textContaining('Duración:'), findsOneWidget);
  });

  testWidgets('diferencia recomendadas realizadas y pendientes',
      (tester) async {
    await _pump(tester, respuestas: {'n1': _conDatos()});
    await tester.scrollUntilVisible(find.text('Insertar piezas'), 200);
    expect(find.text('Pendiente de realizar'), findsOneWidget);
    expect(find.textContaining('Realizada el'), findsOneWidget);
  });

  testWidgets('registrar abre el flujo existente del plan', (tester) async {
    await _pump(tester, respuestas: {'n1': _conDatos()});
    final boton = find.text('Realizar y registrar actividad');
    await tester.scrollUntilVisible(boton, 200);
    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(find.text('PLAN n1'), findsOneWidget);
  });

  testWidgets('estado vacío sin registros ni plan publicado', (tester) async {
    await _pump(tester);
    expect(find.textContaining('No hay actividades registradas'),
        findsOneWidget);
    expect(find.textContaining('se necesita un plan publicado'),
        findsOneWidget);
    expect(find.text('Sin registro'), findsNWidgets(2));
    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets('error de carga y reintento', (tester) async {
    final s = await _pump(tester,
        respuestas: {'n1': _conDatos()}, fallos: 1);
    expect(find.textContaining('No se pudo cargar'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(s.llamadas, hasLength(2));
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('el filtro de periodo consulta el rango correcto',
      (tester) async {
    final s = await _pump(tester, respuestas: {'n1': _conDatos()});
    expect(s.llamadas.last.desde, _hoy().subtract(const Duration(days: 27)));

    await tester.tap(find.text('3 meses'));
    await tester.pumpAndSettle();
    expect(s.llamadas.last.desde, _hoy().subtract(const Duration(days: 89)));
    expect(s.llamadas.last.hasta, _hoy());

    await tester.tap(find.text('12 meses'));
    await tester.pumpAndSettle();
    expect(s.llamadas.last.desde, _hoy().subtract(const Duration(days: 364)));
  });

  testWidgets('cada niño consulta solo su seguimiento', (tester) async {
    final s = await _pump(tester,
        ninos: [_diego, _valeria],
        respuestas: {'n1': _conDatos()},
        pendientes: [_pendiente('n2')]);
    expect(s.llamadas.last.ninoId, 'n1');
    expect(find.textContaining('pendiente de sincronizar'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Valeria Vega'));
    await tester.pumpAndSettle();
    expect(s.llamadas.last.ninoId, 'n2');
    expect(find.textContaining('No hay actividades registradas'),
        findsOneWidget);
    // La actividad offline del dispositivo se informa, sin contarla como hecha.
    expect(find.textContaining('1 actividad guardada en este dispositivo'),
        findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
  });

  for (final size in const [Size(360, 740), Size(800, 1000), Size(1440, 900)]) {
    testWidgets('se adapta sin desbordes a ${size.width.toInt()}px',
        (tester) async {
      await _pump(tester,
          ninos: [_diego, _valeria],
          respuestas: {'n1': _conDatos()},
          size: size);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('12 meses'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
