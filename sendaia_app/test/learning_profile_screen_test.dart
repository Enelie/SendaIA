import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rimai_app/adapters/input/screens/familia/learning_profile_screen.dart';
import 'package:rimai_app/core/providers/dashboard_providers.dart';

/// Servicio de prueba: simula el backend familiar en memoria.
class _FakeService extends DashboardService {
  _FakeService(this.pacientes, {this.failWith}) : super(Dio());

  List<Map<String, dynamic>> pacientes;
  final String? failWith;
  final List<Map<String, dynamic>> patches = [];
  int resumenCalls = 0;

  @override
  Future<DashboardData> obtenerResumenFamilia() async {
    resumenCalls++;
    return DashboardData.fromJson({
      'total_pacientes': pacientes.length,
      'sesiones_esta_semana': 0,
      'alertas_baja_adherencia': 0,
      'pacientes': pacientes,
    });
  }

  @override
  Future<Map<String, dynamic>> actualizarPerfilNino(
      String ninoId, Map<String, dynamic> datos) async {
    if (failWith != null) throw Exception(failWith);
    patches.add({'id': ninoId, ...datos});
    final i = pacientes.indexWhere((p) => p['id'] == ninoId);
    if (i < 0) throw Exception('Niño no encontrado para este tutor');
    pacientes[i] = {
      ...pacientes[i],
      'nombre': datos['nombre'],
      'fecha_nacimiento': datos['fecha_nacimiento'],
      'diagnostico': datos['diagnostico'],
      'hitos': datos['hitos'],
      'sensorial': datos['sensorial'],
      'intereses': datos['intereses'],
      'rutinas_regulacion': datos['rutinas_regulacion'],
      'medicacion_actual': datos['medicacion_actual'],
    };
    return {'id': ninoId, 'nombre': datos['nombre']};
  }
}

Map<String, dynamic> _santiago() => {
      'id': 'n1',
      'nombre': 'Santiago López',
      'fecha_nacimiento': '2018-03-10',
      'edad': 8,
      'nivel_cognitivo': 'Medio',
      'hitos': {
        'comunicacion': 'Palabras sueltas',
        'contacto_visual': 'Intermitente',
        'atencion': 'Bajo',
      },
      'sensorial': {
        'hipersensibilidad': ['Ruidos fuertes'],
        'comportamientos_repetitivos': ['Balanceo'],
      },
      'intereses': ['Dinosaurios', 'Trenes'],
      'estimulos_aversivos': {
        'RUIDO': ['sirenas']
      },
      'rutinas_regulacion': <String>[],
      'recomendaciones_activas': [
        'Conecta la consigna con intereses del nino: Dinosaurios, Trenes.'
      ],
      'plan_activo_id': 'plan-1',
    };

Map<String, dynamic> _valeria() => {
      'id': 'n2',
      'nombre': 'Valeria Vega',
      'fecha_nacimiento': '2017-07-01',
      'edad': 9,
      'nivel_cognitivo': 'Sin datos',
      'hitos': {'atencion': 'Alto'},
      'sensorial': {'lugar_estudio': 'Biblioteca'},
      'intereses': ['Música'],
    };

Future<_FakeService> _pump(WidgetTester tester, List<Map<String, dynamic>> data,
    {String? failWith, Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final service = _FakeService(data, failWith: failWith);
  final router = GoRouter(
    initialLocation: '/familia/perfil',
    routes: [
      GoRoute(
        path: '/familia/perfil',
        builder: (_, __) => const LearningProfileScreen(),
      ),
      GoRoute(
        path: '/familia/plan/:id',
        builder: (_, __) => const Scaffold(body: Text('PLAN')),
      ),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [dashboardServiceProvider.overrideWithValue(service)],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return service;
}

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  // Un campo con foco vuelve a desplazarse a sí mismo; se quita el foco antes.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('consulta el perfil y muestra datos previos y sugerencias',
      (tester) async {
    await _pump(tester, [_santiago()]);

    expect(find.text('Santiago López'), findsWidgets);
    expect(find.text('2018-03-10'), findsOneWidget);
    expect(find.text('No registrado'), findsOneWidget); // diagnóstico opcional
    expect(find.text('Dinosaurios'), findsOneWidget);
    // Campos de registros anteriores se muestran, no se descartan.
    expect(find.text('Información registrada anteriormente'), findsOneWidget);
    expect(find.text('Palabras sueltas'), findsOneWidget);
    expect(find.text('Balanceo'), findsOneWidget);
    expect(find.textContaining('Conecta la consigna'), findsOneWidget);
    // Un solo niño: no se muestra el selector.
    expect(find.text('SELECCIONA UN NIÑO'), findsNothing);
  });

  testWidgets('con varios niños permite seleccionar uno', (tester) async {
    await _pump(tester, [_santiago(), _valeria()]);

    expect(find.text('SELECCIONA UN NIÑO'), findsOneWidget);
    expect(find.text('Palabras sueltas'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Valeria Vega'));
    await tester.pumpAndSettle();

    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Palabras sueltas'), findsNothing);
  });

  testWidgets('valida obligatorios y consentimiento antes de guardar',
      (tester) async {
    final service = await _pump(tester, [_santiago()]);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Santiago López'), '');
    await _tapVisible(tester, find.text('Guardar cambios'));
    expect(find.text('El nombre es obligatorio.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Santiago');
    await _tapVisible(tester, find.text('Guardar cambios'));
    expect(find.textContaining('Confirma el consentimiento'), findsOneWidget);
    expect(service.patches, isEmpty);
  });

  testWidgets('guarda, conserva campos previos y recarga lo persistido',
      (tester) async {
    final service = await _pump(tester, [_santiago(), _valeria()]);
    final callsAntes = service.resumenCalls;

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.widgetWithText(FilterChip, 'Espacio'));
    await _tapVisible(tester, find.byType(CheckboxListTile));
    await _tapVisible(tester, find.text('Guardar cambios'));

    expect(service.patches, hasLength(1));
    final sent = service.patches.single;
    expect(sent['id'], 'n1'); // solo el niño seleccionado
    expect(sent['intereses'], containsAll(['Dinosaurios', 'Trenes', 'Espacio']));
    // El PATCH reemplaza hitos/sensorial: se envían los campos previos.
    expect(sent['hitos']['comunicacion'], 'Palabras sueltas');
    expect(sent['hitos']['contacto_visual'], 'Intermitente');
    expect(sent['sensorial']['comportamientos_repetitivos'], ['Balanceo']);
    expect(sent['estimulos_aversivos'], {
      'RUIDO': ['sirenas']
    });
    expect(sent['nivel_cognitivo'], 'Medio');
    expect(sent['acepta_uso_no_diagnostico'], isTrue);
    expect(sent.containsKey('diagnostico'), isFalse);

    // Se recargó desde el backend y la vista muestra lo persistido.
    expect(service.resumenCalls, greaterThan(callsAntes));
    expect(find.text('Perfil de aprendizaje actualizado.'), findsOneWidget);
    expect(find.text('Espacio'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
  });

  testWidgets('no envía un nivel cognitivo inválido', (tester) async {
    final service = await _pump(tester, [_valeria()]);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byType(CheckboxListTile));
    await _tapVisible(tester, find.text('Guardar cambios'));
    expect(service.patches.single.containsKey('nivel_cognitivo'), isFalse);
  });

  testWidgets('muestra el error del backend y mantiene el formulario',
      (tester) async {
    await _pump(tester, [_santiago()],
        failWith: 'Niño no encontrado para este tutor');
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byType(CheckboxListTile));
    await _tapVisible(tester, find.text('Guardar cambios'));

    expect(find.text('Niño no encontrado para este tutor'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsOneWidget);
  });

  testWidgets('estado vacío sin niños registrados', (tester) async {
    await _pump(tester, []);
    expect(find.text('Aún no has registrado ningún niño.'), findsOneWidget);
  });

  for (final size in const [Size(360, 740), Size(800, 1000), Size(1440, 900)]) {
    testWidgets('se adapta sin desbordes a ${size.width.toInt()}px',
        (tester) async {
      await _pump(tester, [_santiago(), _valeria()], size: size);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
