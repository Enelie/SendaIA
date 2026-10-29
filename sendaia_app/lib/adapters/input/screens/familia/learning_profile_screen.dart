import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rimai_app/adapters/input/widgets/rimai_bottom_nav.dart';
import 'package:rimai_app/core/providers/dashboard_providers.dart';
import 'package:rimai_app/core/providers/pmv2_providers.dart';

// ── Design tokens (mismos que el panel familiar) ─────────────────────────────
const _kP = Color(0xFF5CBF95);
const _kA = Color(0xFFBAB0FF);
const _kBg = Color(0xFFE9F8FF);
const _kSurf = Color(0xFFF6FEFF);
const _kText = Color(0xFF2A2825);
const _kSub = Color(0xFF6B6661);
const _kBdr = Color(0xFFC8E9F7);
const _kLabel = Color(0xFFB08C68);

// ── Opciones (las mismas del asistente de registro de 4 pasos) ───────────────
const _optsAtencion = ['Bajo', 'Moderado', 'Alto'];
const _optsFormaAprende = [
  'Visual (imágenes, demos, esquemas)',
  'Auditivo (explicaciones y lectura en voz alta)',
  'Práctico (manipular y experimentar)',
  'Lectura y escritura',
  'Con apoyo de otra persona',
];
const _optsInstrucciones = [
  'Necesita apoyo paso a paso',
  'Sigue instrucciones simples',
  'Sigue instrucciones de varias pasos',
  'Le cuesta seguir instrucciones',
];
const _optsDistractores = [
  'Ruidos',
  'Pantallas o televisión',
  'Movimiento de otras personas',
  'Conversaciones alrededor',
  'Teléfono o tablet',
  'Temperatura o luces',
];
const _optsFactores = [
  'Poco sueño',
  'Cansancio',
  'Hambre',
  'Ansiedad o preocupaciones',
  'Demasiados estímulos',
  'Falta de rutina',
];
const _optsLugar = [
  'Escritorio o mesa en casa',
  'Su habitación',
  'Comedor o sala',
  'Biblioteca',
  'Otro lugar',
];
const _optsPausas = [
  'Sí, con frecuencia',
  'Sí, de forma ocasional',
  'No necesita pausas',
];
const _optsIntereses = [
  'Dinosaurios',
  'Trenes',
  'Espacio',
  'Geometría',
  'Números',
  'Música',
  'Animales',
];

// Claves que este módulo edita. El resto de claves de `hitos` / `sensorial`
// (registros anteriores: comunicación, contacto visual, perfil sensorial…)
// se muestran como "información registrada" y se conservan al guardar.
const _hitosEditables = {
  'atencion',
  'forma_aprende',
  'actividades_dificiles',
  'seguir_instrucciones',
  'actividades_motivan',
  'estrategias_padre',
};
const _sensorialEditables = {
  'distractores',
  'factores_concentracion',
  'lugar_estudio',
  'rutinas_estudio',
  'pausas',
};

const _etiquetas = {
  'comunicacion': 'Comunicación',
  'contacto_visual': 'Contacto visual',
  'juego_social': 'Juego social',
  'motricidad': 'Motricidad',
  'hipersensibilidad': 'Hipersensibilidad',
  'hiposensibilidad': 'Hiposensibilidad',
  'comportamientos_repetitivos': 'Comportamientos repetitivos',
  'intereses_obsesivos': 'Intereses intensos',
};

const _nivelesCognitivos = {'Bajo', 'Medio', 'Alto'};

/// Perfil de aprendizaje del panel familiar: consulta y edición del perfil
/// educativo de cada niño vinculado al tutor autenticado.
class LearningProfileScreen extends ConsumerStatefulWidget {
  const LearningProfileScreen({super.key, this.initialNinoId});

  final String? initialNinoId;

  @override
  ConsumerState<LearningProfileScreen> createState() =>
      _LearningProfileScreenState();
}

class _LearningProfileScreenState extends ConsumerState<LearningProfileScreen> {
  String? _selectedId;
  bool _editing = false;
  bool _saving = false;
  String? _saveError;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _diagCtrl = TextEditingController();
  final _medCtrl = TextEditingController();
  final _actDificilesCtrl = TextEditingController();
  final _rutinasCtrl = TextEditingController();
  final _motivanCtrl = TextEditingController();
  final _estrategiasCtrl = TextEditingController();
  final _regulacionCtrl = TextEditingController();
  final _otroInteresCtrl = TextEditingController();

  DateTime? _date;
  String _atencion = 'Moderado';
  final Set<String> _formaAprende = {};
  final List<String> _actDificiles = [];
  String _instrucciones = 'Sigue instrucciones simples';
  final Set<String> _distractores = {};
  final Set<String> _factores = {};
  String _lugar = 'Escritorio o mesa en casa';
  final List<String> _rutinas = [];
  String _pausas = 'Sí, de forma ocasional';
  final Set<String> _intereses = {};
  final List<String> _motivan = [];
  final List<String> _estrategias = [];
  final List<String> _regulacion = [];
  bool _consent = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialNinoId;
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _dateCtrl,
      _diagCtrl,
      _medCtrl,
      _actDificilesCtrl,
      _rutinasCtrl,
      _motivanCtrl,
      _estrategiasCtrl,
      _regulacionCtrl,
      _otroInteresCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helpers de datos ───────────────────────────────────────────────────────
  static List<String> _list(dynamic v) {
    if (v is List) {
      return v
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (v is Map) {
      return v.entries
          .expand((e) => e.value is List
              ? (e.value as List).map((x) => '${e.key}: $x')
              : [if (e.value != null && '${e.value}'.isNotEmpty) '${e.key}'])
          .toList();
    }
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? [] : [s];
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _humanize(String key) =>
      _etiquetas[key] ??
      (key.isEmpty
          ? key
          : (key[0].toUpperCase() + key.substring(1)).replaceAll('_', ' '));

  List<String> _pendingRows(List<String> saved, TextEditingController c) =>
      saved
          .followedBy(c.text
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty))
          .toSet()
          .toList();

  PacienteDashboard? _selected(List<PacienteDashboard> ninos) {
    if (ninos.isEmpty) return null;
    return ninos.firstWhere((n) => n.id == _selectedId,
        orElse: () => ninos.first);
  }

  void _startEdit(PacienteDashboard p) {
    final h = p.hitos;
    final s = p.sensorial;
    setState(() {
      _saveError = null;
      _consent = false;
      _nameCtrl.text = p.nombre;
      _date = p.fechaNacimiento != null
          ? DateTime.tryParse(p.fechaNacimiento!)
          : null;
      _dateCtrl.text = _date != null ? _fmtDate(_date!) : '';
      _diagCtrl.text = p.diagnostico ?? '';
      _medCtrl.text = p.medicacionActual ?? '';
      _atencion = h['atencion']?.toString() ?? 'Moderado';
      _formaAprende
        ..clear()
        ..addAll(_list(h['forma_aprende']));
      _actDificiles
        ..clear()
        ..addAll(_list(h['actividades_dificiles']));
      _instrucciones =
          h['seguir_instrucciones']?.toString() ?? 'Sigue instrucciones simples';
      _distractores
        ..clear()
        ..addAll(_list(s['distractores']));
      _factores
        ..clear()
        ..addAll(_list(s['factores_concentracion']));
      _lugar = s['lugar_estudio']?.toString() ?? 'Escritorio o mesa en casa';
      _rutinas
        ..clear()
        ..addAll(_list(s['rutinas_estudio']));
      _pausas = s['pausas']?.toString() ?? 'Sí, de forma ocasional';
      _intereses
        ..clear()
        ..addAll(p.intereses);
      _motivan
        ..clear()
        ..addAll(_list(h['actividades_motivan']));
      _estrategias
        ..clear()
        ..addAll(_list(h['estrategias_padre']));
      _regulacion
        ..clear()
        ..addAll(p.rutinasRegulacion);
      for (final c in [
        _actDificilesCtrl,
        _rutinasCtrl,
        _motivanCtrl,
        _estrategiasCtrl,
        _regulacionCtrl,
        _otroInteresCtrl,
      ]) {
        c.clear();
      }
      _editing = true;
    });
  }

  /// Construye el payload del PATCH existente conservando todo lo que este
  /// formulario no edita (el endpoint reemplaza `hitos` y `sensorial` enteros).
  Map<String, dynamic> _payload(PacienteDashboard p) {
    final hitos = Map<String, dynamic>.from(p.hitos)
      ..addAll({
        'atencion': _atencion,
        'forma_aprende': _formaAprende.toList(),
        'actividades_dificiles': _pendingRows(_actDificiles, _actDificilesCtrl),
        'seguir_instrucciones': _instrucciones,
        'actividades_motivan': _pendingRows(_motivan, _motivanCtrl),
        'estrategias_padre': _pendingRows(_estrategias, _estrategiasCtrl),
      });
    final sensorial = Map<String, dynamic>.from(p.sensorial)
      ..addAll({
        'distractores': _distractores.toList(),
        'factores_concentracion': _factores.toList(),
        'lugar_estudio': _lugar,
        'rutinas_estudio': _pendingRows(_rutinas, _rutinasCtrl),
        'pausas': _pausas,
      });
    final diag = _diagCtrl.text.trim();
    final med = _medCtrl.text.trim();
    return {
      'nombre': _nameCtrl.text.trim(),
      'fecha_nacimiento': _fmtDate(_date!),
      if (_nivelesCognitivos.contains(p.nivelCognitivo))
        'nivel_cognitivo': p.nivelCognitivo,
      if (diag.isNotEmpty) 'diagnostico': diag,
      if (med.isNotEmpty) 'medicacion_actual': med,
      'hitos': hitos,
      'sensorial': sensorial,
      'intereses': _pendingRows(_intereses.toList(), _otroInteresCtrl),
      'estimulos_aversivos': p.estimulosAversivos,
      'rutinas_regulacion': _pendingRows(_regulacion, _regulacionCtrl),
      'consentimiento_datos_sensibles': _consent,
      'consentimiento_informado_version': 'LPDP-29733-v1',
      'acepta_uso_no_diagnostico': _consent,
    };
  }

  Future<void> _save(PacienteDashboard p) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_consent) {
      setState(() => _saveError =
          'Confirma el consentimiento informado para guardar los cambios.');
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final payload = _payload(p);
    try {
      await ref
          .read(dashboardServiceProvider)
          .actualizarPerfilNino(p.id, payload);

      // Recarga desde el backend: los datos y las sugerencias se recalculan
      // a partir del perfil guardado.
      ref.invalidate(familiaDashboardProvider);
      ref.invalidate(perfilPacienteProvider(p.id));
      ref.invalidate(planActivoProvider(p.id));
      final data = await ref.read(familiaDashboardProvider.future);
      final guardado = data.pacientes.where((n) => n.id == p.id).firstOrNull;
      final persistio = guardado != null &&
          guardado.nombre == payload['nombre'] &&
          guardado.intereses.toSet().containsAll(payload['intereses'] as List);

      if (!mounted) return;
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(persistio
            ? 'Perfil de aprendizaje actualizado.'
            : 'Se guardaron los cambios, pero no se pudo confirmar la recarga. Desliza para actualizar.'),
        backgroundColor: persistio ? const Color(0xFF4A52D9) : Colors.orange,
      ));
    } catch (e) {
      if (mounted) {
        setState(() =>
            _saveError = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate:
          _date ?? DateTime.now().subtract(const Duration(days: 365 * 7)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: _kP, onPrimary: Colors.white, onSurface: _kText),
        ),
        child: child!,
      ),
    );
    if (p != null) {
      setState(() {
        _date = p;
        _dateCtrl.text = _fmtDate(p);
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(familiaDashboardProvider);
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg.withValues(alpha: 0.7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: const Row(children: [
          Icon(Icons.school_rounded, color: _kP),
          SizedBox(width: 12),
          Flexible(
            child: Text('Perfil de aprendizaje',
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
            onPressed: () => context.go('/familia/dashboard'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kP)),
        error: (e, _) => _buildError(e.toString()),
        data: (data) {
          final p = _selected(data.pacientes);
          if (p == null) return _buildEmpty();
          return RefreshIndicator(
            color: _kP,
            onRefresh: () async {
              ref.invalidate(familiaDashboardProvider);
              await ref.read(familiaDashboardProvider.future);
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
                      if (data.pacientes.length > 1)
                        _childSelector(data.pacientes, p),
                      _header(p),
                      const SizedBox(height: 16),
                      _editing ? _buildForm(p) : _buildView(p),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _editing
          ? null
          : RimAIBottomNav(
              currentIndex: 1,
              onTap: (index) {
                if (index == 0) context.go('/familia/dashboard');
                if (index == 2) context.go('/familia/seguimiento');
                if (index == 3) context.go('/familia/chatbot');
              },
              items: [
                BottomNavItem(icon: Icons.home_rounded, label: 'Inicio'),
                BottomNavItem(icon: Icons.school_rounded, label: 'Perfil'),
                BottomNavItem(
                    icon: Icons.insights_rounded, label: 'Seguimiento'),
                BottomNavItem(icon: Icons.forum_rounded, label: 'Asistente IA'),
              ],
            ),
    );
  }

  Widget _buildError(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: _kSub),
            const SizedBox(height: 12),
            Text(msg,
                style: const TextStyle(color: _kSub),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(familiaDashboardProvider),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kA, foregroundColor: _kText),
              child: const Text('Reintentar'),
            ),
          ]),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.child_care_rounded, size: 64, color: _kSub),
            const SizedBox(height: 12),
            Text('Aún no has registrado ningún niño.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, color: _kText)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/familia/dashboard'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kA, foregroundColor: _kText),
              child: const Text('Ir a registrar'),
            ),
          ]),
        ),
      );

  Widget _childSelector(List<PacienteDashboard> ninos, PacienteDashboard sel) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Selecciona un niño'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ninos.map((n) {
                final isSel = n.id == sel.id;
                return ChoiceChip(
                  label: Text(n.nombre),
                  selected: isSel,
                  showCheckmark: false,
                  avatar: Icon(Icons.child_care_rounded,
                      size: 16, color: isSel ? _kText : _kSub),
                  // No se cambia de niño con cambios sin guardar.
                  onSelected: _editing
                      ? null
                      : (v) {
                          if (v) setState(() => _selectedId = n.id);
                        },
                  selectedColor: _kA,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                          color: isSel ? _kA : _kBdr.withValues(alpha: 0.5))),
                  labelStyle: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600, fontSize: 13, color: _kText),
                );
              }).toList(),
            ),
          ],
        ),
      );

  Widget _header(PacienteDashboard p) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nombre,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _kText)),
                const SizedBox(height: 4),
                Text(
                  _editing
                      ? 'Editando el perfil de aprendizaje.'
                      : 'Cómo aprende, qué le ayuda y qué le motiva.',
                  style:
                      GoogleFonts.plusJakartaSans(fontSize: 13, color: _kSub),
                ),
              ],
            ),
          ),
          if (!_editing)
            FilledButton.icon(
              onPressed: () => _startEdit(p),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar'),
              style: FilledButton.styleFrom(
                backgroundColor: _kA,
                foregroundColor: _kText,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
        ],
      );

  // ══════════════════════════════════════════════════════════════════════════
  // CONSULTA
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildView(PacienteDashboard p) {
    final h = p.hitos;
    final s = p.sensorial;

    final otrosHitos = h.entries
        .where((e) => !_hitosEditables.contains(e.key))
        .map((e) => MapEntry(_humanize(e.key), _list(e.value)))
        .where((e) => e.value.isNotEmpty)
        .toList();
    final otrosSensorial = s.entries
        .where((e) => !_sensorialEditables.contains(e.key))
        .map((e) => MapEntry(_humanize(e.key), _list(e.value)))
        .where((e) => e.value.isNotEmpty)
        .toList();
    final aversivos = _list(p.estimulosAversivos);
    final documentos = p.documentosClinicos.entries
        .where((e) => e.value != null && '${e.value}'.isNotEmpty)
        .map((e) => e.value is Map
            ? (e.value as Map)['nombre']?.toString() ?? _humanize(e.key)
            : _humanize(e.key))
        .toList();

    final sections = <Widget>[
      _section('Datos básicos', Icons.badge_outlined, [
        _row('Nombre', [p.nombre]),
        _row('Fecha de nacimiento',
            [if (p.fechaNacimiento != null) p.fechaNacimiento!]),
        _row('Edad', [if (p.fechaNacimiento != null) '${p.edad} años']),
        _row('Diagnóstico previo (opcional)',
            [if ((p.diagnostico ?? '').isNotEmpty) p.diagnostico!],
            empty: 'No registrado'),
      ]),
      _section('Cómo aprende', Icons.lightbulb_outline_rounded, [
        _row('Atención / concentración', _list(h['atencion'])),
        _row('Aprende mejor con', _list(h['forma_aprende'])),
        _row('Actividades que le resultan difíciles',
            _list(h['actividades_dificiles'])),
        _row('Seguimiento de instrucciones', _list(h['seguir_instrucciones'])),
      ]),
      _section('Entorno de estudio', Icons.home_work_outlined, [
        _row('Principales distractores', _list(s['distractores'])),
        _row('Factores que dificultan la concentración',
            _list(s['factores_concentracion'])),
        _row('Lugar habitual de estudio', _list(s['lugar_estudio'])),
        _row('Rutinas de estudio', _list(s['rutinas_estudio'])),
        _row('Necesidad de pausas', _list(s['pausas'])),
      ]),
      _section('Intereses y motivación', Icons.favorite_border_rounded, [
        _row('Intereses principales', p.intereses),
        _row('Actividades que lo motivan', _list(h['actividades_motivan'])),
        _row('Estrategias que usa la familia', _list(h['estrategias_padre'])),
        _row('Rutinas de regulación / calma', p.rutinasRegulacion),
      ]),
      if (otrosHitos.isNotEmpty ||
          otrosSensorial.isNotEmpty ||
          aversivos.isNotEmpty)
        _section(
          'Información registrada anteriormente',
          Icons.history_rounded,
          [
            _note(
                'Datos de registros previos (hitos y perfil sensorial). Se conservan al editar.'),
            ...otrosHitos.map((e) => _row(e.key, e.value)),
            ...otrosSensorial.map((e) => _row(e.key, e.value)),
            if (aversivos.isNotEmpty) _row('Estímulos que le molestan', aversivos),
          ],
        ),
      _section('Antecedentes y medicación', Icons.medical_information_outlined, [
        _note(
            'Información aportada por la familia. SendaIA no realiza diagnósticos.'),
        _row('Medicación actual',
            [if ((p.medicacionActual ?? '').isNotEmpty) p.medicacionActual!],
            empty: 'No registrada'),
        _row('Documentos adjuntos', documentos, empty: 'Ninguno'),
      ]),
      _suggestionsSection(p),
    ];

    return LayoutBuilder(builder: (context, c) {
      final twoCols = c.maxWidth >= 720;
      final w = twoCols ? (c.maxWidth - 16) / 2 : c.maxWidth;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: sections.map((s) => SizedBox(width: w, child: s)).toList(),
      );
    });
  }

  Widget _suggestionsSection(PacienteDashboard p) => _section(
        'Sugerencias que usan este perfil',
        Icons.auto_awesome_outlined,
        [
          if (p.recomendacionesActivas.isEmpty)
            _note(p.planActivoId == null
                ? 'Las sugerencias aparecerán cuando haya actividades publicadas para ${p.nombre}. Se adaptan a sus intereses y rutinas registradas.'
                : 'Aún no hay sugerencias generadas para las actividades actuales.')
          else ...[
            _note(
                'Se actualizan automáticamente al guardar cambios en intereses y rutinas.'),
            ...p.recomendacionesActivas.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_circle_outline,
                            size: 16, color: _kP),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(r,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, color: _kText, height: 1.35)),
                      ),
                    ],
                  ),
                )),
          ],
          if (p.planActivoId != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push('/familia/plan/${p.id}'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Ver actividades sugeridas'),
                style: TextButton.styleFrom(foregroundColor: _kP),
              ),
            ),
        ],
      );

  Widget _section(String title, IconData icon, List<Widget> children) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kSurf,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kBdr.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 20, color: _kP),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _kText)),
              ),
            ]),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      );

  Widget _row(String label, List<String> values, {String empty = 'Sin registrar'}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(label),
            if (values.isEmpty)
              Text(empty,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: _kSub.withValues(alpha: 0.7)))
            else if (values.length == 1)
              Text(values.first,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kText))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: values
                    .map((v) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: _kBdr),
                          ),
                          child: Text(v,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _kText)),
                        ))
                    .toList(),
              ),
          ],
        ),
      );

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: _kSub, height: 1.4)),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _kLabel,
                letterSpacing: 0.8)),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // EDICIÓN
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildForm(PacienteDashboard p) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _section('Datos básicos', Icons.badge_outlined, [
                _textField('Nombre del niño', _nameCtrl,
                    hint: 'Ej: Mateo García',
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'El nombre es obligatorio.'
                        : null),
                _label('Fecha de nacimiento'),
                TextFormField(
                  controller: _dateCtrl,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: _dec('Seleccionar fecha',
                      icon: Icons.calendar_today),
                  validator: (_) => _date == null
                      ? 'La fecha de nacimiento es obligatoria.'
                      : null,
                ),
                const SizedBox(height: 16),
                _textField('Diagnóstico previo de TDAH (opcional)', _diagCtrl,
                    hint: 'Ej: TDAH diagnosticado por especialista'),
              ]),
              const SizedBox(height: 16),
              _section('Cómo aprende', Icons.lightbulb_outline_rounded, [
                _choice('Atención / concentración', _optsAtencion, _atencion,
                    (v) => setState(() => _atencion = v)),
                _multi('Aprende mejor con', _optsFormaAprende, _formaAprende),
                _rows('Actividades que le resultan difíciles',
                    'Ej: escribir textos, matemáticas', _actDificilesCtrl,
                    _actDificiles),
                _choice('Seguimiento de instrucciones', _optsInstrucciones,
                    _instrucciones, (v) => setState(() => _instrucciones = v)),
              ]),
              const SizedBox(height: 16),
              _section('Entorno de estudio', Icons.home_work_outlined, [
                _multi(
                    'Principales distractores', _optsDistractores, _distractores),
                _multi('Factores que dificultan la concentración',
                    _optsFactores, _factores),
                _choice('Lugar habitual de estudio', _optsLugar, _lugar,
                    (v) => setState(() => _lugar = v)),
                _rows('Rutinas de estudio',
                    'Ej: 20 minutos de tarea y 5 de descanso', _rutinasCtrl,
                    _rutinas),
                _choice('Necesidad de pausas', _optsPausas, _pausas,
                    (v) => setState(() => _pausas = v)),
              ]),
              const SizedBox(height: 16),
              _section('Intereses y motivación', Icons.favorite_border_rounded,
                  [
                _multi('Intereses principales', _optsIntereses, _intereses),
                _rows('Otro interés', 'Ej: dibujo, fútbol', _otroInteresCtrl,
                    null, onAdd: (rows) => _intereses.addAll(rows)),
                _rows('Actividades que lo motivan',
                    'Ej: juegos de mesa, pintar', _motivanCtrl, _motivan),
                _rows('Estrategias que usa la familia',
                    'Ej: horario fijo, temporizador', _estrategiasCtrl,
                    _estrategias),
                _rows('Rutinas de regulación / calma',
                    'Ej: respirar profundo antes de empezar', _regulacionCtrl,
                    _regulacion),
              ]),
              const SizedBox(height: 16),
              _section('Antecedentes y medicación',
                  Icons.medical_information_outlined, [
                _textField('Medicación actual (opcional)', _medCtrl,
                    hint: 'Solo si un profesional la indicó'),
                _note(
                    'Los documentos adjuntos y la información registrada anteriormente se conservan sin cambios.'),
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kBdr),
                ),
                child: CheckboxListTile(
                  value: _consent,
                  onChanged: (v) => setState(() {
                    _consent = v ?? false;
                    if (_consent) _saveError = null;
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: _kP,
                  title: Text('Consentimiento informado',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800, color: _kText)),
                  subtitle: Text(
                    'Confirmo el tratamiento de datos sensibles del nino conforme a la Ley N. 29733 y entiendo que SendaIA es una herramienta de apoyo al aprendizaje, no un diagnostico.',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: _kSub, height: 1.35),
                  ),
                ),
              ),
              if (_saveError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: Colors.red.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_saveError!,
                          style: TextStyle(color: Colors.red.shade900)),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              _editing = false;
                              _saveError = null;
                            }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kSub,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _saving ? null : () => _save(p),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kA,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text('Guardar cambios',
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String hint, {IconData? icon}) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: icon != null ? Icon(icon, color: _kA, size: 20) : null,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _kBdr.withValues(alpha: 0.5))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _kBdr.withValues(alpha: 0.5))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _kA, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.plusJakartaSans(
            color: _kSub.withValues(alpha: 0.4), fontSize: 14),
      );

  Widget _textField(String label, TextEditingController ctrl,
          {String hint = '', FormFieldValidator<String>? validator}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(label),
            TextFormField(
              controller: ctrl,
              decoration: _dec(hint),
              validator: validator,
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600, color: _kText),
            ),
          ],
        ),
      );

  /// Opciones del asistente + el valor guardado si no está entre ellas, para
  /// no perder valores de registros anteriores.
  List<String> _withCurrent(List<String> opts, Iterable<String> current) =>
      [...opts, ...current.where((c) => !opts.contains(c))];

  Widget _chip(String o, bool sel, ValueChanged<bool> onSelected) => FilterChip(
        label: Text(o),
        selected: sel,
        showCheckmark: false,
        avatar: sel ? const Icon(Icons.check, size: 16, color: _kText) : null,
        onSelected: onSelected,
        selectedColor: _kA,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(color: sel ? _kA : _kBdr.withValues(alpha: 0.5))),
        labelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600, fontSize: 13, color: _kText),
      );

  Widget _choice(String label, List<String> opts, String current,
          ValueChanged<String> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(label),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _withCurrent(opts, [current])
                  .map((o) => _chip(o, o == current, (v) {
                        if (v) onChanged(o);
                      }))
                  .toList(),
            ),
          ],
        ),
      );

  Widget _multi(String label, List<String> opts, Set<String> current) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(label),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _withCurrent(opts, current)
                  .map((o) => _chip(
                      o,
                      current.contains(o),
                      (_) => setState(() =>
                          current.contains(o) ? current.remove(o) : current.add(o))))
                  .toList(),
            ),
          ],
        ),
      );

  /// Lista editable de filas de texto. Si [target] es null, las filas se
  /// entregan a [onAdd] (p. ej. para sumarlas a un conjunto de chips).
  Widget _rows(String label, String hint, TextEditingController ctrl,
      List<String>? target,
      {void Function(List<String>)? onAdd}) {
    void add() {
      final rows = ctrl.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (rows.isEmpty) return;
      setState(() {
        if (target != null) {
          target.addAll(rows.where((r) => !target.contains(r)));
        }
        onAdd?.call(rows);
        ctrl.clear();
      });
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: ctrl,
                decoration: _dec(hint),
                onFieldSubmitted: (_) => add(),
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: add,
                style: FilledButton.styleFrom(
                  backgroundColor: _kA,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Icon(Icons.add, size: 20),
              ),
            ),
          ]),
          if (target != null && target.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: target
                  .map((r) => InputChip(
                        label: Text(r),
                        onDeleted: () => setState(() => target.remove(r)),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: _kBdr),
                        labelStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kText),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
