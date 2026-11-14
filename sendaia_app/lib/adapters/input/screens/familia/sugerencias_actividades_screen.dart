import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import 'package:rimai_app/adapters/input/widgets/rimai_bottom_nav.dart';
import 'package:rimai_app/core/providers/dashboard_providers.dart';
import 'package:rimai_app/core/providers/familia_sugerencias_providers.dart';
import 'package:rimai_app/core/providers/seguimiento_providers.dart';

// ── Design tokens (misma paleta del panel familiar) ───────────────────────────
const _kP = Color(0xFF5CBF95);
const _kA = Color(0xFFBAB0FF);
const _kBg = Color(0xFFE9F8FF);
const _kText = Color(0xFF2A2825);
const _kSub = Color(0xFF6B6661);
const _kBdr = Color(0xFFC8E9F7);

/// Módulo independiente de "Sugerencias de actividades" del panel familiar.
class SugerenciasActividadesScreen extends ConsumerStatefulWidget {
  final String? ninoId;
  const SugerenciasActividadesScreen({super.key, this.ninoId});

  @override
  ConsumerState<SugerenciasActividadesScreen> createState() =>
      _SugerenciasActividadesState();
}

class _SugerenciasActividadesState
    extends ConsumerState<SugerenciasActividadesScreen> {
  String? _ninoId;
  String _filtroArea = 'Todas';
  final Set<String> _registradas = <String>{};
  final Uuid _uuid = const Uuid();

  static const _areasDisponibles = [
    'Todas',
    'Comprensión lectora',
    'Expresión escrita',
    'Razonamiento lógico',
    'Análisis',
    'Autonomía',
    'Pausas y autorregulación',
  ];

  void _seleccionar(String id) {
    if (_ninoId == id) return;
    setState(() {
      _ninoId = id;
      _filtroArea = 'Todas';
    });
  }

  void _abrirActividadGuiada(PacienteDashboard p, SugerenciaActividad s) {
    context.push(
      '/familia/sugerencias/actividad?nino=${Uri.encodeQueryComponent(p.id)}',
      extra: s,
    );
  }

  Future<void> _registrarEnCasa(PacienteDashboard p, SugerenciaActividad s) async {
    final data = await showModalBottomSheet<_RegistroRapidoData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RegistroRapidoSheet(nombre: s.nombre),
    );
    if (data == null || !mounted) return;

    try {
      await ref.read(seguimientoServiceProvider).registrarActividadFamiliar(
            ninoId: p.id,
            actividadId: s.actividadId,
            modalidad: 'casa_sin_app',
            nivelAyudaRequerido: data.nivelAyuda,
            observaciones: data.observaciones,
            clientEventId: _uuid.v4(),
          );
      if (!mounted) return;
      setState(() => _registradas.add(s.actividadId));
      ref.invalidate(seguimientoFamiliarProvider);
      ref.invalidate(familiaDashboardProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Actividad registrada. Ya aparece en Seguimiento y en Inicio.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: _kP,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFB45309),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(familiaDashboardProvider);
    final pacientes =
        async.valueOrNull?.pacientes ?? const <PacienteDashboard>[];
    final selectedId = _resolverNinoId(pacientes);
    final childQuery = selectedId == null
        ? ''
        : '?nino=${Uri.encodeQueryComponent(selectedId)}';
    return Scaffold(
      backgroundColor: _kBg,
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: _kP)),
        error: (e, _) => _errorPanel(e.toString()),
        data: (data) => _contenido(data.pacientes),
      ),
      bottomNavigationBar: RimAIBottomNav(
        currentIndex: 3,
        onTap: (index) {
          if (index == 0) context.go('/familia/dashboard$childQuery');
          if (index == 1) context.go('/familia/perfil$childQuery');
          if (index == 2) context.go('/familia/seguimiento$childQuery');
          if (index == 4) context.go('/familia/chatbot$childQuery');
        },
        items: [
          BottomNavItem(icon: Icons.home_rounded, label: 'Inicio'),
          BottomNavItem(icon: Icons.school_rounded, label: 'Perfil'),
          BottomNavItem(icon: Icons.insights_rounded, label: 'Seguimiento'),
          BottomNavItem(
              icon: Icons.auto_awesome_outlined, label: 'Sugerencias'),
          BottomNavItem(icon: Icons.forum_rounded, label: 'Asistente IA'),
        ],
      ),
    );
  }

  /// Niño activo: el elegido en pantalla, el que llega por URL o el primero.
  String? _resolverNinoId(List<PacienteDashboard> pacientes) {
    if (pacientes.isEmpty) return null;
    if (_ninoId != null && pacientes.any((p) => p.id == _ninoId)) {
      return _ninoId;
    }
    if (widget.ninoId != null &&
        pacientes.any((p) => p.id == widget.ninoId)) {
      return widget.ninoId;
    }
    return pacientes.first.id;
  }

  Widget _errorPanel(String msg) => SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 56, color: _kSub),
                const SizedBox(height: 12),
                Text(msg,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(color: _kSub)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(familiaDashboardProvider),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _kA, foregroundColor: _kText),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );

  // ── Contenido principal ────────────────────────────────────────────────────
  Widget _contenido(List<PacienteDashboard> pacientes) {
    if (pacientes.isEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _titulo(),
              const SizedBox(height: 24),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.child_care_outlined,
                        size: 36, color: _kP),
                    const SizedBox(height: 12),
                    Text('Todavía no hay un perfil de aprendizaje',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _kText)),
                    const SizedBox(height: 6),
                    Text(
                      'Primero registra a tu hijo y completa su perfil de '
                      'aprendizaje: la IA usará sus intereses y su forma de '
                      'aprender para sugerirte actividades para casa.',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          height: 1.4,
                          color: _kSub,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Registrar a mi hijo'),
                        onPressed: () => context.go('/familia/dashboard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kP,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final id = _resolverNinoId(pacientes)!;
    final nino = pacientes.firstWhere((p) => p.id == id);

    return SafeArea(
      child: RefreshIndicator(
        color: _kP,
        onRefresh: () async => ref.invalidate(familiaDashboardProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _titulo(),
              const SizedBox(height: 16),
              if (pacientes.length > 1) ...[
                _etiqueta('ELIGE A TU HIJO'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: pacientes
                      .map((p) => ChoiceChip(
                            label: Text(p.nombre),
                            selected: p.id == id,
                            onSelected: (_) => _seleccionar(p.id),
                            selectedColor: _kA.withValues(alpha: 0.55),
                            backgroundColor: Colors.white,
                            side: BorderSide(
                                color: _kBdr.withValues(alpha: 0.9)),
                            labelStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _kText,
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
              _perfilResumen(nino),
              const SizedBox(height: 16),
              _zonaSugerencias(nino),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titulo() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sugerencias\nde actividades',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _kText,
                height: 1.2,
              )),
          const SizedBox(height: 6),
          Text(
            'Actividades recomendadas por IA a partir del perfil de '
            'aprendizaje, con sus motivos y consejos para casa.',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _kSub,
                height: 1.4),
          ),
        ],
      );

  Widget _etiqueta(String texto) => Text(texto,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF5A738E)));

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBdr.withValues(alpha: 0.5)),
        ),
        child: child,
      );

  // ── Perfil muy resumido del niño ───────────────────────────────────────────
  Widget _perfilResumen(PacienteDashboard p) {
    final hitos = p.hitos;
    final sensorial = p.sensorial;
    final intereses = p.intereses.take(4).toList();
    final atencion = (hitos['atencion'] ?? '').toString();
    final formas = hitos['forma_aprende'];
    final forma = (formas is List && formas.isNotEmpty)
        ? formas.first.toString().split('(').first.trim()
        : '';
    final distractores = sensorial['distractores'];
    final distractoresTxt = (distractores is List)
        ? distractores.take(2).map((e) => e.toString()).toList()
        : <String>[];
    final dificiles = hitos['actividades_dificiles'];
    final dificilesTxt = (dificiles is List)
        ? dificiles.take(2).map((e) => e.toString()).toList()
        : <String>[];
    final datos = <String>[
      if (intereses.isNotEmpty) 'intereses',
      if (atencion.isNotEmpty) 'atencion',
      if (forma.isNotEmpty) 'forma',
      if (distractoresTxt.isNotEmpty) 'distractores',
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: 17, color: _kP),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Este es el perfil de ${p.nombre}',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: _kText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${p.edad} años · Nivel cognitivo ${p.nivelCognitivo}',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5, fontWeight: FontWeight.w600, color: _kSub),
          ),
          const SizedBox(height: 10),
          if (intereses.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: intereses
                  .map((i) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kA.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(i,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _kText)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
          ],
          _datoFila('Atención / concentración', atencion),
          _datoFila('Aprende mejor con', forma),
          _datoFila('Distractores', distractoresTxt.join(', ')),
          _datoFila('Áreas difíciles', dificilesTxt.join(', ')),
          if (datos.length < 3) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 14, color: Color(0xFFB08C68)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'El perfil está incompleto: cuanto más datos registres, '
                    'más precisas serán las sugerencias.',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: _kSub),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go('/familia/dashboard'),
              icon: const Icon(Icons.edit_outlined, size: 15),
              label: Text('Editar perfil de aprendizaje',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4A52D9),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _datoFila(String label, String valor) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 132,
              child: Text(label,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF5A738E))),
            ),
            Expanded(
              child: Text(
                valor.isEmpty ? 'sin registrar' : valor,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: valor.isEmpty ? const Color(0xFF9CA3AF) : _kText),
              ),
            ),
          ],
        ),
      );

  // ── Zona de sugerencias (carga automática + resultados) ────────────────────
  Widget _zonaSugerencias(PacienteDashboard p) {
    // El provider no es autoDispose: mientras dure la sesión de la app, al
    // cambiar de pestaña las sugerencias ya cargadas se muestran de inmediato
    // sin volver a pulsar ningún botón.
    final async = ref.watch(sugerenciasFamiliaProvider(p.id));

    return async.when(
      loading: () => _card(
        child: Column(
          children: [
            const SizedBox(height: 6),
            const CircularProgressIndicator(color: Color(0xFF7B6CF6)),
            const SizedBox(height: 14),
            Text('Preparando las actividades para casa de ${p.nombre}...',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kText)),
            const SizedBox(height: 4),
            Text(
              'Adaptando comprensión lectora, expresión escrita, razonamiento '
              'lógico, análisis, autonomía y pausas a su perfil y atención.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w500, color: _kSub),
            ),
          ],
        ),
      ),
      error: (e, _) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 18, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('No pudimos generar las sugerencias',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _kText)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('$e',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, height: 1.35, color: _kSub)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  ref.invalidate(sugerenciasFamiliaProvider(p.id)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kP,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10)),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
      data: (datos) => _resultados(p, datos),
    );
  }

  Widget _resultados(PacienteDashboard p, SugerenciasFamilia datos) {
    final filtradas = _filtroArea == 'Todas'
        ? datos.sugerencias
        : datos.sugerencias
            .where((s) => s.areaEducativa == _filtroArea || s.tipo == _filtroArea)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined,
                      size: 17, color: Color(0xFF7B6CF6)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Actividades recomendadas para casa',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _kText),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        ref.invalidate(sugerenciasFamiliaProvider(p.id)),
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Recalcular'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Nivel pedagógico: ${datos.dificultadEstimada} · '
                'Confianza adaptativa: ${(datos.confianzaModelo * 100).toInt()}%',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _kSub),
              ),
              if (!datos.perfilCompleto) ...[
                const SizedBox(height: 8),
                Text(
                  'Completa el perfil de aprendizaje para personalizar aún más estas sugerencias.',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _kP),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Actividades para casa',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _kText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Elige una actividad para acompañar a ${p.nombre}. Puedes guiarla con el celular al lado o registrarla si la hicieron como tarea en casa.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _kSub,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _areasDisponibles.map((area) {
              final sel = _filtroArea == area;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(area),
                  selected: sel,
                  onSelected: (_) => setState(() => _filtroArea = area),
                  selectedColor: _kA.withValues(alpha: 0.55),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: _kBdr.withValues(alpha: 0.9)),
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: sel ? _kText : _kSub,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        if (filtradas.isEmpty)
          _card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No hay actividades en "$_filtroArea". Elige "Todas" para ver más opciones.',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _kSub),
                ),
              ),
            ),
          )
        else
          ...filtradas.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _tarjetaSugerencia(p, s),
              )),
        if (datos.nota.isNotEmpty) ...[
          const SizedBox(height: 6),
          _card(
            child: Text(
              datos.nota,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: _kSub),
            ),
          ),
        ],
      ],
    );
  }

  Widget _tarjetaSugerencia(PacienteDashboard p, SugerenciaActividad s) {
    final registrada = _registradas.contains(s.actividadId);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBdr.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kA.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  s.areaEducativa,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4A52D9),
                  ),
                ),
              ),
              _chip(s.nivelDificultad, _kP.withValues(alpha: 0.2)),
              if (s.duracionSegundos > 0)
                _chip('${(s.duracionSegundos / 60).round()} min',
                    Colors.grey.shade100),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.nombre,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: _kText),
          ),
          if (s.instrucciones != null && s.instrucciones!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(s.instrucciones!,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: _kText)),
          ],
          if (s.motivos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('POR QUÉ SE ELIGIÓ',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF5A738E))),
            ...s.motivos.map(
              (m) => Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 14, color: _kP),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(m,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: _kText)),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (s.consejos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('CONSEJOS EN CASA',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF5A738E))),
            ...s.consejos.map(
              (c) => Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.tips_and_updates_outlined,
                        size: 14, color: Color(0xFFB08C68)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(c,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: _kSub)),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (s.materiales.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Materiales: ${s.materiales.join(', ')}',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _kSub)),
          ],
          const SizedBox(height: 12),
          if (registrada)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _kP.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 18, color: _kP),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Registrada. Ya aparece en Seguimiento y en Inicio.',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kText),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _abrirActividadGuiada(p, s),
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: const Text('Hacer con la app'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B6CF6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _registrarEnCasa(p, s),
                icon: const Icon(Icons.home_outlined, size: 18),
                label: const Text('Ya la hizo en casa'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kText,
                  side: BorderSide(color: _kBdr.withValues(alpha: 0.9)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String texto, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(texto,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: _kText)),
      );
}

class _RegistroRapidoData {
  final int nivelAyuda;
  final String? observaciones;

  const _RegistroRapidoData({
    required this.nivelAyuda,
    this.observaciones,
  });
}

/// Hoja para registrar en segundos una actividad hecha en casa sin la app.
class _RegistroRapidoSheet extends StatefulWidget {
  final String nombre;
  const _RegistroRapidoSheet({required this.nombre});

  @override
  State<_RegistroRapidoSheet> createState() => _RegistroRapidoSheetState();
}

class _RegistroRapidoSheetState extends State<_RegistroRapidoSheet> {
  int _nivel = 0;
  final TextEditingController _obs = TextEditingController();

  @override
  void dispose() {
    _obs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _kBdr,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('¿Ya hicieron esta actividad?',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _kText)),
                const SizedBox(height: 4),
                Text(
                  'Registra "${widget.nombre}" como hecha en casa. No hace '
                  'falta que el terapeuta haya publicado un plan.',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: _kSub),
                ),
                const SizedBox(height: 16),
                Text('¿NECESITÓ AYUDA?',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF5A738E))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _nivelChip(0, 'Sin ayuda'),
                    _nivelChip(1, 'Un poco'),
                    _nivelChip(2, 'Bastante'),
                  ],
                ),
                const SizedBox(height: 16),
                Text('OBSERVACIONES (OPCIONAL)',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF5A738E))),
                const SizedBox(height: 8),
                TextField(
                  controller: _obs,
                  maxLines: 3,
                  maxLength: 500,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Ej. Le costó empezar, pero terminó contento.',
                    hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5, color: _kSub),
                    filled: true,
                    fillColor: _kBg,
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _kBdr),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _kBdr),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kP, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(
                      _RegistroRapidoData(
                        nivelAyuda: _nivel,
                        observaciones: _obs.text,
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Registrar en casa'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kP,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancelar',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kSub)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _nivelChip(int valor, String texto) {
    final sel = _nivel == valor;
    return ChoiceChip(
      label: Text(texto),
      selected: sel,
      onSelected: (_) => setState(() => _nivel = valor),
      selectedColor: _kA.withValues(alpha: 0.55),
      backgroundColor: _kBg,
      side: BorderSide(color: sel ? _kA : _kBdr),
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: _kText,
      ),
    );
  }
}
