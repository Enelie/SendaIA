import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:rimai_app/adapters/input/widgets/rimai_bottom_nav.dart';
import 'package:rimai_app/core/providers/dashboard_providers.dart';
import 'package:rimai_app/core/providers/familia_sugerencias_providers.dart';

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
  final Set<String> _solicitados = <String>{};

  void _seleccionar(String id) {
    if (_ninoId == id) return;
    setState(() => _ninoId = id);
  }

  void _solicitar(String id) {
    setState(() => _solicitados.add(id));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(familiaDashboardProvider);
    return Scaffold(
      backgroundColor: _kBg,
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: _kP)),
        error: (e, _) => _errorPanel(e.toString()),
        data: (data) => _contenido(data.pacientes),
      ),
      bottomNavigationBar: RimAIBottomNav(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) context.go('/familia/dashboard');
          if (index == 2) context.go('/familia/chatbot');
        },
        items: [
          BottomNavItem(icon: Icons.home_rounded, label: 'Inicio'),
          BottomNavItem(
              icon: Icons.auto_awesome_outlined, label: 'Sugerencias'),
          BottomNavItem(icon: Icons.forum_rounded, label: 'Asistente IA'),
        ],
      ),
    );
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

    final id = _ninoId ??
        (widget.ninoId != null &&
                pacientes.any((p) => p.id == widget.ninoId)
            ? widget.ninoId
            : null) ??
        pacientes.first.id;
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

  // ── Zona de sugerencias (botón + resultados) ───────────────────────────────
  Widget _zonaSugerencias(PacienteDashboard p) {
    final solicitado = _solicitados.contains(p.id);

    if (!solicitado) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined,
                    size: 18, color: Color(0xFF7B6CF6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¿Qué actividades necesita ${p.nombre}?',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _kText),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'La IA analizará su perfil de aprendizaje (intereses, '
              'dificultades, atención y entorno) y te mostrará las '
              'actividades recomendadas, por qué se eligieron y consejos '
              'para realizarlas en casa.',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: _kSub),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 17),
                label: const Text('Brindarme las sugerencias con IA'),
                onPressed: () => _solicitar(p.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B6CF6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final resultados = ref.watch(sugerenciasFamiliaProvider(p.id));
    return resultados.when(
      loading: () => _card(
        child: Column(
          children: [
            const SizedBox(height: 6),
            const CircularProgressIndicator(color: Color(0xFF7B6CF6)),
            const SizedBox(height: 14),
            Text('Analizando el perfil de ${p.nombre} con IA...',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kText)),
            const SizedBox(height: 4),
            Text('Seleccionando las actividades más adecuadas.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, fontWeight: FontWeight.w500, color: _kSub)),
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
            Row(
              children: [
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
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () =>
                      setState(() => _solicitados.remove(p.id)),
                  child: Text('Volver',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kSub)),
                ),
              ],
            ),
          ],
        ),
      ),
      data: (datos) => _resultados(p, datos),
    );
  }

  Widget _resultados(PacienteDashboard p, SugerenciasFamilia datos) {
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
                      'Según su perfil, estas son las actividades '
                      'recomendadas',
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
                'Nivel sugerido: ${datos.dificultadEstimada} · '
                'Datos del perfil usados: '
                '${datos.camposPerfilUsados.length}',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _kSub),
              ),
              if (!datos.perfilCompleto) ...[
                const SizedBox(height: 8),
                Text(
                  'Completa el perfil de aprendizaje para personalizar '
                  'aún más estas sugerencias.',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _kP),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (datos.sugerencias.isEmpty)
          _card(
            child: Text(
              'Aún no hay actividades disponibles para sugerir.',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kSub),
            ),
          )
        else
          ...datos.sugerencias.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _tarjetaSugerencia(s),
              )),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (datos.nota.isNotEmpty)
                Text(
                  datos.nota,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: _kSub),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => ref
                          .invalidate(sugerenciasFamiliaProvider(p.id)),
                      icon: const Icon(Icons.refresh, size: 15),
                      label: Text('Calcular de nuevo',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4A52D9),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 34),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tarjetaSugerencia(SugerenciaActividad s) {
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
          Row(
            children: [
              Expanded(
                child: Text(
                  s.nombre,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kText),
                ),
              ),
              _chip(s.nivelDificultad, _kA.withValues(alpha: 0.4)),
              if (s.duracionSegundos > 0) ...[
                const SizedBox(width: 6),
                _chip('${(s.duracionSegundos / 60).round()} min',
                    _kP.withValues(alpha: 0.2)),
              ],
            ],
          ),
          if (s.tipo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(s.tipo,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5A738E))),
          ],
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
