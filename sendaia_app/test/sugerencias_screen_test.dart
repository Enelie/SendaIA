import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rimai_app/adapters/input/screens/familia/sugerencias_actividades_screen.dart';
import 'package:rimai_app/core/providers/dashboard_providers.dart';
import 'package:rimai_app/core/providers/familia_sugerencias_providers.dart';

PacienteDashboard _nino(String id, String nombre) => PacienteDashboard(
      id: id,
      nombre: nombre,
      edad: 8,
      nivelCognitivo: 'Bajo',
      intereses: const ['Espacio'],
      hitos: const {'atencion': 'Bajo'},
      sensorial: const {'distractores': ['Ruidos']},
    );

SugerenciasFamilia _respuesta(String ninoId, String nombre) =>
    SugerenciasFamilia(
      ninoId: ninoId,
      ninoNombre: nombre,
      dificultadEstimada: 'Medio',
      confianzaModelo: 0.8,
      perfilCompleto: true,
      camposPerfilUsados: const ['intereses', 'nivel_atencion'],
      sugerencias: const [
        SugerenciaActividad(
          actividadId: 'a1',
          nombre: 'Contacto visual 5 seg',
          tipo: 'Social',
          nivelDificultad: 'Medio',
          duracionSegundos: 180,
          duracionMinutos: 3,
          instrucciones: 'Mantener contacto visual durante 5 segundos.',
          materiales: [],
          puntuacion: 8,
          motivos: ['Dificultad Medio, acorde al nivel estimado'],
          consejos: ['Hazlo en un lugar tranquilo.'],
        ),
      ],
      totalCatalogo: 8,
      nota: 'No constituye indicacion clinica.',
    );

void main() {
  testWidgets('el modulo cambia de nino y muestra las sugerencias',
      (tester) async {
    final data = DashboardData(
      totalPacientes: 2,
      sesionesEstaSemana: 0,
      alertasBajaAdherencia: 0,
      pacientes: [_nino('id-ana', 'Ana Torres'), _nino('id-luis', 'Luis Ramos')],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          familiaDashboardProvider.overrideWith((ref) async => data),
          sugerenciasFamiliaProvider
              .overrideWith((ref, ninoId) async => _respuesta(
                    ninoId,
                    ninoId == 'id-ana' ? 'Ana Torres' : 'Luis Ramos',
                  )),
        ],
        child: const MaterialApp(
          home: SugerenciasActividadesScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Este es el perfil de Ana Torres'),
        findsOneWidget);

    await tester.tap(find.text('Luis Ramos'));
    await tester.pump();
    expect(find.textContaining('Este es el perfil de Luis Ramos'),
        findsOneWidget);

    await tester.ensureVisible(
        find.text('Brindarme las sugerencias con IA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Brindarme las sugerencias con IA'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Contacto visual 5 seg'), findsOneWidget);
    expect(find.textContaining('Dificultad Medio'), findsOneWidget);
    expect(find.textContaining('Hazlo en un lugar tranquilo.'),
        findsOneWidget);
    expect(find.textContaining('No constituye indicacion clinica.'),
        findsOneWidget);
  });
}
