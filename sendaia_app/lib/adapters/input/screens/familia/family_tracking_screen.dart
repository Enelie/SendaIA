import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rimai_app/adapters/input/widgets/rimai_bottom_nav.dart';
import 'package:rimai_app/core/providers/dashboard_providers.dart';
import 'package:rimai_app/core/providers/seguimiento_providers.dart';
import 'package:rimai_app/domain/entities/actividad_local.dart';

// ── Design tokens (mismos que el panel familiar) ─────────────────────────────
const _kP = Color(0xFF5CBF95);
const _kA = Color(0xFFBAB0FF);
const _kBg = Color(0xFFE9F8FF);
const _kSurf = Color(0xFFF6FEFF);
const _kText = Color(0xFF2A2825);
const _kSub = Color(0xFF6B6661);
const _kBdr = Color(0xFFC8E9F7);
const _kLabel = Color(0xFFB08C68);

const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

const _nivelesAyuda = {0: 'Sin ayuda', 1: 'Ayuda verbal', 2: 'Ayuda física'};

/// Periodos de consulta: el backend filtra por fecha, así que el filtro se
/// aplica sobre todos los registros del rango.
enum _Periodo {
  semanas4('4 semanas', 27),
  meses3('3 meses', 89),
  meses12('12 meses', 364);

  const _Periodo(this.label, this.dias);
  final String label;
  final int dias;
}

/// Seguimiento familiar: qué actividades se realizaron en casa y qué
/// resultados se registraron. Las sugerencias siguen en su propio módulo.
class FamilyTrackingScreen extends ConsumerStatefulWidget {
  const FamilyTrackingScreen({super.key, this.initialNinoId});

  final String? initialNinoId;

  @override
  ConsumerState<FamilyTrackingScreen> createState() =>
      _FamilyTrackingScreenState();
}

class _FamilyTrackingScreenState extends ConsumerState<FamilyTrackingScreen> {
  String? _selectedId;
  _Periodo _periodo = _Periodo.semanas4;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialNinoId;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  SeguimientoArgs _args(String ninoId) {
    final hasta = _day(DateTime.now());
    return (
      ninoId: ninoId,
      desde: hasta.subtract(Duration(days: _periodo.dias)),
      hasta: hasta,
    );
  }

  static String _fecha(DateTime d) =>
      '${d.day} ${_meses[d.month - 1]} ${d.year}';

  static String _fechaHora(DateTime d) =>
      '${_fecha(d)} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _duracion(double segundos) {
    final total = segundos.round();
    if (total < 60) return '$total s';
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    return h > 0 ? '$h h $m min' : '$m min';
  }

  @override
  Widget build(BuildContext context) {
    final familia = ref.watch(familiaDashboardProvider);
    final childQuery = _selectedId == null
        ? ''
        : '?nino=${Uri.encodeQueryComponent(_selectedId!)}';
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg.withValues(alpha: 0.7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: const Row(children: [
          Icon(Icons.insights_rounded, color: _kP),
          SizedBox(width: 12),
          Flexible(
            child: Text('Seguimiento familiar',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 20, color: _kP)),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: 'Inicio',
            icon: const Icon(Icons.home_rounded,
                color: Color.fromARGB(255, 60, 59, 88)),
            onPressed: () => context.go('/familia/dashboard$childQuery'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: familia.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kP)),
        error: (e, _) => _mensaje(Icons.cloud_off_rounded, e.toString(),
            accion: 'Reintentar',
            onAccion: () => ref.invalidate(familiaDashboardProvider)),
        data: (data) {
          if (data.pacientes.isEmpty) {
            return _mensaje(Icons.child_care_rounded,
                'Aún no has registrado ningún niño.',
                accion: 'Ir a registrar',
                onAccion: () => context.go('/familia/dashboard$childQuery'));
          }
          final nino = data.pacientes.firstWhere(
              (n) => n.id == _selectedId,
              orElse: () => data.pacientes.first);
          return _buildBody(data.pacientes, nino);
        },
      ),
      bottomNavigationBar: RimAIBottomNav(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            context.go('/familia/dashboard$childQuery');
          }
          if (index == 1) {
            context.go('/familia/perfil$childQuery');
          }
          if (index == 3) {
            context.go('/familia/chatbot$childQuery');
          }
        },
        items: [
          BottomNavItem(icon: Icons.home_rounded, label: 'Inicio'),
          BottomNavItem(icon: Icons.school_rounded, label: 'Perfil'),
          BottomNavItem(icon: Icons.insights_rounded, label: 'Seguimiento'),
          BottomNavItem(icon: Icons.forum_rounded, label: 'Asistente IA'),
        ],
      ),
    );
  }

  Widget _buildBody(List<PacienteDashboard> ninos, PacienteDashboard nino) {
    final args = _args(nino.id);
    final seguimiento = ref.watch(seguimientoFamiliarProvider(args));
    final pendientes =
        ref.watch(actividadesPendientesSyncProvider(nino.id)).valueOrNull ??
            const <ActividadLocal>[];

    return RefreshIndicator(
      color: _kP,
      onRefresh: () async {
        ref.invalidate(seguimientoFamiliarProvider(args));
        ref.invalidate(actividadesPendientesSyncProvider(nino.id));
        await ref.read(seguimientoFamiliarProvider(args).future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ninos.length > 1) _selector(ninos, nino),
                Text(nino.nombre,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _kText)),
                const SizedBox(height: 4),
                Text('Actividades realizadas en casa y resultados registrados.',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: _kSub)),
                const SizedBox(height: 12),
                _periodoSelector(),
                const SizedBox(height: 16),
                if (pendientes.isNotEmpty) ...[
                  _pendientesBanner(pendientes.length),
                  const SizedBox(height: 16),
                ],
                seguimiento.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                        child: CircularProgressIndicator(color: _kP)),
                  ),
                  error: (e, _) => _card(child: _errorContent(e, args)),
                  data: (s) => _buildContent(nino, s),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(PacienteDashboard nino, SeguimientoFamiliar s) {
    final sinRegistros = s.registros.isEmpty;
    return LayoutBuilder(builder: (context, c) {
      final ancho = c.maxWidth >= 720;
      final grafica = _graficaSemanal(s);
      final recomendadas = _recomendadas(nino, s);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _indicadores(s, c.maxWidth),
          const SizedBox(height: 16),
          if (sinRegistros)
            _card(
              child: _vacio(
                  'No hay actividades registradas en los últimos ${_periodo.label}.',
                  'Cuando completes una actividad recomendada y guardes sus resultados, aparecerá aquí.'),
            )
          else if (ancho)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: grafica),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: recomendadas),
            ])
          else ...[
            grafica,
          ],
          if (sinRegistros || !ancho) ...[
            const SizedBox(height: 16),
            recomendadas,
          ],
          if (!sinRegistros) ...[
            const SizedBox(height: 16),
            _historial(s),
          ],
        ],
      );
    });
  }

  // ── Encabezado ───────────────────────────────────────────────────────────
  Widget _selector(List<PacienteDashboard> ninos, PacienteDashboard sel) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Selecciona un niño'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ninos
                  .map((n) => _chip(n.nombre, n.id == sel.id,
                      () => setState(() => _selectedId = n.id),
                      icon: Icons.child_care_rounded))
                  .toList(),
            ),
          ],
        ),
      );

  Widget _periodoSelector() => Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Periodo:',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _kSub)),
          ..._Periodo.values.map((p) =>
              _chip(p.label, p == _periodo, () => setState(() => _periodo = p))),
        ],
      );

  Widget _chip(String text, bool selected, VoidCallback onTap,
          {IconData? icon}) =>
      ChoiceChip(
        label: Text(text),
        selected: selected,
        showCheckmark: false,
        avatar: icon != null
            ? Icon(icon, size: 16, color: selected ? _kText : _kSub)
            : null,
        onSelected: (v) {
          if (v) onTap();
        },
        selectedColor: _kA,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(
                color: selected ? _kA : _kBdr.withValues(alpha: 0.5))),
        labelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600, fontSize: 13, color: _kText),
      );

  Widget _pendientesBanner(int n) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF2CC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          const Icon(Icons.cloud_upload_outlined, color: Color(0xFF8A5A00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              n == 1
                  ? '1 actividad guardada en este dispositivo está pendiente de sincronizar. Aparecerá en el historial cuando haya conexión.'
                  : '$n actividades guardadas en este dispositivo están pendientes de sincronizar. Aparecerán en el historial cuando haya conexión.',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF6B4300),
                  fontWeight: FontWeight.w600,
                  height: 1.35),
            ),
          ),
        ]),
      );

  // ── Indicadores ──────────────────────────────────────────────────────────
  Widget _indicadores(SeguimientoFamiliar s, double ancho) {
    final tiles = [
      _tile(Icons.task_alt_rounded, 'Actividades realizadas',
          '${s.actividadesCompletadas}'),
      _tile(Icons.calendar_month_outlined, 'Días con actividad',
          '${s.diasConActividad}'),
      _tile(
          Icons.timer_outlined,
          'Tiempo registrado',
          s.registrosConDuracion > 0 && s.segundosTotales != null
              ? _duracion(s.segundosTotales!)
              : 'Sin registro'),
      _tile(Icons.check_circle_outline, 'Intentos correctos',
          s.intentos > 0 ? '${s.aciertos} de ${s.intentos}' : 'Sin registro'),
    ];
    final columnas = ancho >= 720 ? 4 : 2;
    final w = (ancho - 12 * (columnas - 1)) / columnas;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: tiles.map((t) => SizedBox(width: w, child: t)).toList(),
    );
  }

  Widget _tile(IconData icon, String label, String value) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: _kP),
            const SizedBox(height: 8),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kText)),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 2,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: _kSub, height: 1.3)),
          ],
        ),
      );

  // ── Gráfica semanal ──────────────────────────────────────────────────────
  /// Semanas (lunes) del rango, con 0 en las semanas sin registros.
  List<SemanaActividad> _serieSemanal(SeguimientoFamiliar s) {
    DateTime lunes(DateTime d) => _day(d).subtract(Duration(days: d.weekday - 1));
    final porSemana = {for (final w in s.porSemana) lunes(w.semana): w};
    final serie = <SemanaActividad>[];
    for (var w = lunes(s.desde);
        !w.isAfter(s.hasta);
        w = DateTime(w.year, w.month, w.day + 7)) {
      serie.add(porSemana[w] ?? SemanaActividad(semana: w, actividades: 0));
    }
    return serie;
  }

  Widget _graficaSemanal(SeguimientoFamiliar s) {
    final serie = _serieSemanal(s);
    final maxY = math.max(1, serie.map((w) => w.actividades).fold(0, math.max));
    final paso = math.max(1, (serie.length / 6).ceil());
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titulo(Icons.bar_chart_rounded, 'Actividades realizadas por semana'),
          const SizedBox(height: 4),
          Text('Solo cuenta actividades completadas y guardadas.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kSub)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxY.toDouble() + (maxY < 4 ? 1 : maxY * 0.15),
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: math.max(1, (maxY / 4).ceilToDouble()),
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: _kBdr.withValues(alpha: 0.7), strokeWidth: 1),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, __) {
                      final w = serie[group.x];
                      return BarTooltipItem(
                        'Semana del ${w.semana.day} ${_meses[w.semana.month - 1]}\n${w.actividades} actividad${w.actividades == 1 ? '' : 'es'}',
                        const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: math.max(1, (maxY / 4).ceilToDouble()),
                      getTitlesWidget: (v, _) => Text('${v.toInt()}',
                          style: const TextStyle(fontSize: 11, color: _kSub)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i % paso != 0 || i >= serie.length) {
                          return const SizedBox.shrink();
                        }
                        final d = serie[i].semana;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('${d.day} ${_meses[d.month - 1]}',
                              style:
                                  const TextStyle(fontSize: 10, color: _kSub)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < serie.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: serie[i].actividades.toDouble(),
                        color: _kP,
                        width: serie.length > 20 ? 5 : 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Recomendadas vs. realizadas ──────────────────────────────────────────
  Widget _recomendadas(PacienteDashboard nino, SeguimientoFamiliar s) =>
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo(Icons.checklist_rounded, 'Actividades recomendadas'),
            const SizedBox(height: 4),
            Text('Estado de las actividades publicadas para la familia.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kSub)),
            const SizedBox(height: 12),
            if (s.recomendadas.isEmpty)
              Text(
                'Aún no hay actividades publicadas para ${nino.nombre}. Para registrar una actividad se necesita un plan publicado.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: _kSub, height: 1.4),
              )
            else ...[
              ...s.recomendadas.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Icon(
                          r.realizada
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: r.realizada ? _kP : _kSub),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.nombre,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _kText)),
                            Text(
                                r.realizada && r.ultimaRealizacion != null
                                    ? 'Realizada el ${_fecha(r.ultimaRealizacion!)}'
                                    : 'Pendiente de realizar',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12, color: _kSub)),
                          ],
                        ),
                      ),
                    ]),
                  )),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push('/familia/plan/${nino.id}'),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Realizar y registrar actividad'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kA,
                    foregroundColor: _kText,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ],
        ),
      );

  // ── Historial ────────────────────────────────────────────────────────────
  Widget _historial(SeguimientoFamiliar s) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo(Icons.history_rounded, 'Historial de actividades'),
            const SizedBox(height: 12),
            ...s.registros.map(_registro),
            if (s.registrosTruncados)
              Text(
                  'Se muestran los ${s.registros.length} registros más recientes del periodo.',
                  style:
                      GoogleFonts.plusJakartaSans(fontSize: 12, color: _kSub)),
          ],
        ),
      );

  Widget _registro(RegistroActividad r) {
    final completada = r.estado == 'completada';
    final detalles = <String>[
      if (r.duracionSegundos != null)
        'Duración: ${_duracion(r.duracionSegundos!)}'
            '${r.duracionEstimadaSegundos != null && r.duracionEstimadaSegundos! > 0 ? ' (estimada ${_duracion(r.duracionEstimadaSegundos!.toDouble())})' : ''}',
      if (r.intentos != null && r.intentos! > 0)
        'Resultado: ${r.aciertos ?? 0} de ${r.intentos} intentos correctos',
      if (r.nivelAyuda != null && _nivelesAyuda.containsKey(r.nivelAyuda))
        _nivelesAyuda[r.nivelAyuda]!,
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(r.actividadNombre,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kText)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: completada
                    ? _kP.withValues(alpha: 0.15)
                    : const Color(0xFFFFF2CC),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                  completada
                      ? 'Completada'
                      : r.estado == 'interrumpida'
                          ? 'Interrumpida'
                          : 'Pendiente de sincronizar',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: completada
                          ? const Color(0xFF2E7D5B)
                          : const Color(0xFF8A5A00))),
            ),
          ]),
          if (r.fecha != null) ...[
            const SizedBox(height: 2),
            Text(_fechaHora(r.fecha!),
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kSub)),
          ],
          if (detalles.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...detalles.map((d) => Text(d,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: _kText, height: 1.4))),
          ],
          if ((r.observaciones ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('“${r.observaciones}”',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: _kSub,
                    height: 1.4)),
          ],
        ],
      ),
    );
  }

  // ── Helpers visuales ─────────────────────────────────────────────────────
  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kSurf,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kBdr.withValues(alpha: 0.5)),
        ),
        child: child,
      );

  Widget _titulo(IconData icon, String text) => Row(children: [
        Icon(icon, size: 20, color: _kP),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w800, color: _kText)),
        ),
      ]);

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _kLabel,
                letterSpacing: 0.8)),
      );

  Widget _vacio(String titulo, String detalle) => Column(children: [
        const Icon(Icons.event_note_outlined, size: 48, color: _kSub),
        const SizedBox(height: 10),
        Text(titulo,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, color: _kText)),
        const SizedBox(height: 4),
        Text(detalle,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: _kSub, height: 1.4)),
      ]);

  Widget _errorContent(Object e, SeguimientoArgs args) => Column(children: [
        const Icon(Icons.cloud_off_rounded, size: 48, color: _kSub),
        const SizedBox(height: 10),
        Text(e.toString().replaceFirst('Exception: ', ''),
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kSub)),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => ref.invalidate(seguimientoFamiliarProvider(args)),
          style: ElevatedButton.styleFrom(
              backgroundColor: _kA, foregroundColor: _kText),
          child: const Text('Reintentar'),
        ),
      ]);

  Widget _mensaje(IconData icon, String texto,
          {required String accion, required VoidCallback onAccion}) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 64, color: _kSub),
            const SizedBox(height: 12),
            Text(texto,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, color: _kText)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAccion,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kA, foregroundColor: _kText),
              child: Text(accion),
            ),
          ]),
        ),
      );
}
