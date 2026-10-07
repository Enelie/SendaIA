import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rimai_app/core/providers/dashboard_providers.dart';
import 'package:rimai_app/core/providers/auth_providers.dart';
import 'package:rimai_app/adapters/input/widgets/rimai_bottom_nav.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kP = Color(0xFF5CBF95);
const _kA = Color(0xFFBAB0FF);
const _kBg = Color(0xFFE9F8FF);
const _kSurf = Color(0xFFF6FEFF);
const _kText = Color(0xFF2A2825);
const _kSub = Color(0xFF6B6661);
const _kBdr = Color(0xFFC8E9F7);

// ── Screen ────────────────────────────────────────────────────────────────────
class FamiliaDashboardScreen extends ConsumerStatefulWidget {
  const FamiliaDashboardScreen({super.key});
  @override
  ConsumerState<FamiliaDashboardScreen> createState() => _State();
}

class _State extends ConsumerState<FamiliaDashboardScreen> {
  // Wizard control
  bool _wizardMode = false;
  int _step = 0;
  final _pc = PageController();
  bool _saving = false;
  String? _editingNinoId;

  // Step 1
  final _nameCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _diagCtrl = TextEditingController();
  DateTime? _date;
  String _nivelCognitivo = 'Bajo';

  // Step 2 — Perfil de aprendizaje
  String _atencion = 'Moderado';
  final Set<String> _formaAprende = {};
  final _actDificilesCtrl = TextEditingController();
  final List<String> _actDificiles = [];
  String _instrucciones = 'Sigue instrucciones simples';

  // Step 3 — Entorno y aprendizaje
  final Set<String> _distractores = {};
  final Set<String> _factores = {};
  String _lugarEstudio = 'Escritorio o mesa en casa';
  final _rutinaCtrl = TextEditingController();
  final List<String> _rutinas = [];
  String _pausas = 'Sí, de forma ocasional';

  // Step 4 — Intereses y resumen
  final Set<String> _int = {};
  final _motivanCtrl = TextEditingController();
  final List<String> _motivan = [];
  final _estrategiasCtrl = TextEditingController();
  final List<String> _estrategias = [];
  bool _acceptedPrivacyConsent = false;

  @override
  void dispose() {
    _pc.dispose();
    _nameCtrl.dispose();
    _dateCtrl.dispose();
    _diagCtrl.dispose();
    _actDificilesCtrl.dispose();
    _rutinaCtrl.dispose();
    _motivanCtrl.dispose();
    _estrategiasCtrl.dispose();
    super.dispose();
  }

  void _tog(Set<String> s, String v) =>
      setState(() => s.contains(v) ? s.remove(v) : s.add(v));

  List<String> _currentRows(
    List<String> savedRows,
    TextEditingController controller,
  ) {
    return controller.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .followedBy(savedRows)
        .toSet()
        .toList();
  }

  void _addRow(List<String> target, TextEditingController controller) {
    final rows = controller.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (rows.isEmpty) return;
    setState(() {
      target.addAll(rows.where((row) => !target.contains(row)));
      controller.clear();
    });
  }

  void _removeRow(List<String> target, String row) {
    setState(() => target.remove(row));
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate:
          _date ?? DateTime.now().subtract(const Duration(days: 365 * 5)),
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
        _dateCtrl.text =
            '${p.year}-${p.month.toString().padLeft(2, '0')}-${p.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _next() {
    if (_step == 0 && (_nameCtrl.text.trim().isEmpty || _date == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nombre y fecha de nacimiento son obligatorios.')),
      );
      return;
    }
    if (_step == 3 && !_acceptedPrivacyConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Confirma el consentimiento informado y el uso no diagnostico para continuar.',
          ),
        ),
      );
      return;
    }
    if (_step < 3) {
      setState(() => _step++);
      _pc.animateToPage(_step,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _guardar();
    }
  }

  void _prev() {
    if (_step > 0) {
      setState(() => _step--);
      _pc.animateToPage(_step,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      setState(() {
        _reset();
        _wizardMode = false;
        _step = 0;
      });
    }
  }

  Map<String, dynamic> _perfilPayload() {
    return {
      'nombre': _nameCtrl.text.trim(),
      'fecha_nacimiento': _dateCtrl.text,
      'nivel_cognitivo': _nivelCognitivo,
      if (_diagCtrl.text.trim().isNotEmpty)
        'diagnostico': _diagCtrl.text.trim(),
      'hitos': {
        'atencion': _atencion,
        'forma_aprende': _formaAprende.toList(),
        'actividades_dificiles': _currentRows(_actDificiles, _actDificilesCtrl),
        'seguir_instrucciones': _instrucciones,
        'actividades_motivan': _currentRows(_motivan, _motivanCtrl),
        'estrategias_padre': _currentRows(_estrategias, _estrategiasCtrl),
      },
      'sensorial': {
        'distractores': _distractores.toList(),
        'factores_concentracion': _factores.toList(),
        'lugar_estudio': _lugarEstudio,
        'rutinas_estudio': _currentRows(_rutinas, _rutinaCtrl),
        'pausas': _pausas,
      },
      'intereses': _int.toList(),
      'consentimiento_datos_sensibles': _acceptedPrivacyConsent,
      'consentimiento_informado_version': 'LPDP-29733-v1',
      'acepta_uso_no_diagnostico': _acceptedPrivacyConsent,
    };
  }

  Future<void> _guardar() async {
    setState(() => _saving = true);
    try {
      final nombreRegistrado = _nameCtrl.text.trim();
      final debeSugerirScqLocal = _debeSugerirScq();
      final editingId = _editingNinoId;
      final service = ref.read(dashboardServiceProvider);
      final result = editingId == null
          ? await service.guardarPerfilNino(_perfilPayload())
          : await service.actualizarPerfilNino(editingId, _perfilPayload());
      final ninoId = result['id']?.toString() ?? '';
      final requiereScq = editingId == null &&
          (result['requiere_scq'] == true || debeSugerirScqLocal);
      ref.invalidate(familiaDashboardProvider);
      setState(() {
        _wizardMode = false;
        _step = 0;
        _reset();
      });
      if (mounted) {
        if (requiereScq && ninoId.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showScqPrompt(ninoId, nombreRegistrado);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(editingId == null
                ? 'Niño registrado correctamente.'
                : 'Registro actualizado correctamente.'),
            backgroundColor: const Color(0xFF4A52D9),
            duration: const Duration(seconds: 4),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade800),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _debeSugerirScq() {
    return _diagCtrl.text.trim().isEmpty;
  }

  void _reset() {
    _editingNinoId = null;
    _nameCtrl.clear();
    _dateCtrl.clear();
    _diagCtrl.clear();
    _date = null;
    _nivelCognitivo = 'Bajo';
    _atencion = 'Moderado';
    _formaAprende.clear();
    _actDificilesCtrl.clear();
    _actDificiles.clear();
    _instrucciones = 'Sigue instrucciones simples';
    _distractores.clear();
    _factores.clear();
    _lugarEstudio = 'Escritorio o mesa en casa';
    _rutinaCtrl.clear();
    _rutinas.clear();
    _pausas = 'Sí, de forma ocasional';
    _int.clear();
    _motivanCtrl.clear();
    _motivan.clear();
    _estrategiasCtrl.clear();
    _estrategias.clear();
    _acceptedPrivacyConsent = false;
  }

  List<String> _listFrom(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  void _editarPaciente(PacienteDashboard p) {
    final fecha = p.fechaNacimiento;
    final hitos = p.hitos;
    final sensorial = p.sensorial;
    setState(() {
      _reset();
      _editingNinoId = p.id;
      _wizardMode = true;
      _step = 0;
      _nameCtrl.text = p.nombre;
      _dateCtrl.text = fecha ?? '';
      _date = fecha != null ? DateTime.tryParse(fecha) : null;
      _diagCtrl.text = p.diagnostico ?? '';
      _nivelCognitivo = p.nivelCognitivo.isNotEmpty ? p.nivelCognitivo : 'Bajo';

      // Perfil de aprendizaje (paso 2)
      _atencion = hitos['atencion']?.toString() ?? _atencion;
      _formaAprende.addAll(_listFrom(hitos['forma_aprende']));
      _actDificiles.addAll(_listFrom(hitos['actividades_dificiles']));
      _instrucciones =
          hitos['seguir_instrucciones']?.toString() ?? _instrucciones;

      // Entorno y aprendizaje (paso 3)
      _distractores.addAll(_listFrom(sensorial['distractores']));
      _factores.addAll(_listFrom(sensorial['factores_concentracion']));
      _lugarEstudio = sensorial['lugar_estudio']?.toString() ?? _lugarEstudio;
      _rutinas.addAll(_listFrom(sensorial['rutinas_estudio']));
      _pausas = sensorial['pausas']?.toString() ?? _pausas;

      // Intereses y resumen (paso 4)
      _motivan.addAll(_listFrom(hitos['actividades_motivan']));
      _estrategias.addAll(_listFrom(hitos['estrategias_padre']));
      _int.addAll(p.intereses.isNotEmpty
          ? p.intereses
          : _listFrom(sensorial['intereses_obsesivos']));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pc.hasClients) _pc.jumpToPage(0);
    });
  }

  Future<void> _confirmarEliminar(PacienteDashboard p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: Text(
          'Se ocultara el registro de ${p.nombre} del panel familiar y de la bandeja del terapeuta. Esta accion no elimina tu cuenta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await ref.read(dashboardServiceProvider).eliminarPerfilNino(p.id);
      ref.invalidate(familiaDashboardProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro eliminado correctamente.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade800),
        );
      }
    }
  }

  void _showScqPrompt(String ninoId, String nombre) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cuestionario SCQ sugerido'),
        content: Text(
          'No registraste informes, plan previo ni medicacion para $nombre. Puedes responder el SCQ como orientacion preliminar antes de enviar el caso al terapeuta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Luego'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push(
                  '/padre/scq/$ninoId?nombre=${Uri.encodeComponent(nombre)}');
            },
            child: const Text('Responder SCQ'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(familiaDashboardProvider);
    return async.when(
      loading: () => const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kP)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: _kBg,
        body: _buildError(e.toString()),
      ),
      data: (data) {
        final showWizard = _wizardMode || data.pacientes.isEmpty;
        return Scaffold(
          backgroundColor: _kBg,
          body: showWizard
              ? _buildWizard(data.pacientes.isNotEmpty)
              : _buildStatus(data),
          bottomNavigationBar: showWizard
              ? null
              : RimAIBottomNav(
                  currentIndex: 0,
                  onTap: (index) {
                    if (index == 1) {
                      context.go('/familia/chatbot');
                    }
                  },
                  items: [
                    BottomNavItem(icon: Icons.home_rounded, label: 'Inicio'),
                    BottomNavItem(
                        icon: Icons.forum_rounded, label: 'Asistente IA'),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildError(String msg) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 64, color: _kSub),
        const SizedBox(height: 12),
        Text(msg,
            style: const TextStyle(color: _kSub), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => ref.invalidate(familiaDashboardProvider),
          style: ElevatedButton.styleFrom(
              backgroundColor: _kA, foregroundColor: _kText),
          child: const Text('Reintentar'),
        ),
      ]));

  // ══════════════════════════════════════════════════════════════════════════
  // STATUS VIEW
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStatus(DashboardData data) {
    return SafeArea(
        child: Column(children: [
      _topBar(showAdd: true),
      Expanded(
          child: RefreshIndicator(
        color: _kP,
        onRefresh: () async => ref.invalidate(familiaDashboardProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Seguimiento\nfamiliar',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _kText,
                  height: 1.2,
                )),
            const SizedBox(height: 6),
            Text(
                '${data.totalPacientes} niño${data.totalPacientes != 1 ? 's' : ''} registrado${data.totalPacientes != 1 ? 's' : ''}',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF5A738E))),
            const SizedBox(height: 4),
            Text(
                'Aquí podrás consultar recomendaciones y seguimiento del aprendizaje.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _kSub)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _FamilyMetricPill(
                    icon: Icons.event_available_outlined,
                    label: 'Esta semana',
                    value: '${data.sesionesEstaSemana}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FamilyMetricPill(
                    icon: Icons.notification_important_outlined,
                    label: 'Alertas',
                    value: '${data.alertasBajaAdherencia}',
                    accent: data.alertasBajaAdherencia > 0 ? _kP : _kA,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...data.pacientes.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _PatientCard(
                    p: p,
                    onEdit: () => _editarPaciente(p),
                    onDelete: () => _confirmarEliminar(p),
                  ),
                )),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon:
                      const Icon(Icons.add, color: Color(0xFFB08C68), size: 20),
                  label: const Text('Registrar otro niño'),
                  onPressed: () => setState(() {
                    _reset();
                    _wizardMode = true;
                    _step = 0;
                  }),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFB08C68),
                    side: const BorderSide(color: _kA, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                )),
          ]),
        ),
      )),
    ]));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WIZARD
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildWizard(bool canGoBack) {
    const titles = [
      'Datos básicos',
      'Perfil de aprendizaje',
      'Entorno y aprendizaje',
      'Intereses y resumen'
    ];
    const subs = [
      'Información general del niño.',
      'Cómo aprende mejor y qué le resulta difícil.',
      'Distractores, lugar y rutinas de estudio.',
      'Intereses, motivación y resumen del perfil.',
    ];
    return SafeArea(
        child: Column(children: [
      _topBar(
          showAdd: false,
          canBack: canGoBack,
          onBack: () => setState(() {
                _reset();
                _wizardMode = false;
                _step = 0;
              })),
      // Progress
      Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Paso ${_step + 1}/4',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: _kSub,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${((_step + 1) / 4 * 100).toInt()}%',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: _kA, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_step + 1) / 4,
                  backgroundColor: const Color(0xFFD8F3FF),
                  valueColor: const AlwaysStoppedAnimation<Color>(_kA),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 14),
              Text(titles[_step],
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _kText)),
              Text(subs[_step],
                  style:
                      GoogleFonts.plusJakartaSans(fontSize: 13, color: _kSub)),
            ],
          )),
      const SizedBox(height: 8),
      // Pages
      Expanded(
          child: PageView(
        controller: _pc,
        physics: const NeverScrollableScrollPhysics(),
        children: [_page1(), _page2(), _page3(), _page4()],
      )),
      // Nav
      _navBar(),
    ]));
  }

  Widget _navBar() => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
            color: _kBg,
            border: Border(top: BorderSide(color: _kBdr.withOpacity(0.5)))),
        child: Row(children: [
          if (_step > 0) ...[
            Expanded(
                child: OutlinedButton(
              onPressed: _prev,
              style: OutlinedButton.styleFrom(
                  foregroundColor: _kSub,
                  side: BorderSide(color: _kBdr.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
              child: Text('Atrás',
                  style:
                      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            )),
            const SizedBox(width: 12),
          ],
          Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _saving ? null : _next,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _kA,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        _step == 3
                            ? (_editingNinoId == null
                                ? 'Registrar paciente'
                                : 'Guardar cambios')
                            : 'Siguiente',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold, fontSize: 15)),
              )),
        ]),
      );

  Widget _topBar(
      {required bool showAdd, bool canBack = false, VoidCallback? onBack}) {
    final notifAsync = ref.watch(notificacionesProvider);
    final unreadCount =
        notifAsync.valueOrNull?.where((n) => !n.leido).length ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        if (canBack && onBack != null) ...[
          IconButton(
              icon:
                  const Icon(Icons.arrow_back_ios_new, size: 18, color: _kSub),
              onPressed: onBack),
          const SizedBox(width: 4),
        ],
        // Logotipo SendaIA premium con doble círculo lila coherente y texto oscuro
        SizedBox(
          width: 24,
          height: 14,
          child: Stack(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kA, width: 2.5),
                ),
              ),
              Positioned(
                left: 8,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: _kA, width: 2.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text('SendaIA',
            style: GoogleFonts.plusJakartaSans(
                color: _kText, fontSize: 18, fontWeight: FontWeight.bold)),
        const Spacer(),
        if (showAdd)
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: _kA, size: 26),
            tooltip: 'Registrar otro niño',
            onPressed: () => setState(() {
              _reset();
              _wizardMode = true;
              _step = 0;
            }),
          ),
        IconButton(
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text('$unreadCount'),
            backgroundColor: _kP,
            child: const Icon(Icons.notifications_active_outlined,
                color: _kSub, size: 22),
          ),
          tooltip: 'Notificaciones',
          onPressed: () => _mostrarNotificacionesModal(),
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: _kSub, size: 20),
          onPressed: () async {
            await ref.read(authStorageProvider).clearSession();
            if (mounted) context.go('/auth/login');
          },
        ),
      ]),
    );
  }

  void _mostrarNotificacionesModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final async = ref.watch(notificacionesProvider);
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _kSub.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Text(
                          'Centro de Notificaciones',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _kText,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.notifications_outlined, color: _kP),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: _kBdr, height: 1),
                  Expanded(
                    child: async.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: _kP),
                      ),
                      error: (err, _) => Center(
                        child: Text(
                          'Error al cargar notificaciones: $err',
                          style: const TextStyle(color: _kSub),
                        ),
                      ),
                      data: (list) {
                        if (list.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.notifications_off_outlined,
                                  size: 48,
                                  color: _kSub.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No tienes notificaciones aún',
                                  style: TextStyle(
                                    color: _kSub.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final n = list[index];
                            return Opacity(
                              opacity: n.leido ? 0.65 : 1.0,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: n.leido ? _kSurf : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: n.leido ? Colors.transparent : _kBdr,
                                    width: 1,
                                  ),
                                  boxShadow: n.leido
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: _kP.withValues(alpha: 0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (!n.leido)
                                          Container(
                                            margin:
                                                const EdgeInsets.only(right: 8),
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: _kP,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        Expanded(
                                          child: Text(
                                            n.titulo,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: n.leido ? _kSub : _kText,
                                            ),
                                          ),
                                        ),
                                        if (!n.leido)
                                          IconButton(
                                            icon: const Icon(Icons.done,
                                                size: 18, color: _kP),
                                            tooltip: 'Marcar como leída',
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                            onPressed: () async {
                                              try {
                                                await ref
                                                    .read(
                                                        dashboardServiceProvider)
                                                    .marcarNotificacionLeida(
                                                        n.id);
                                                ref.invalidate(
                                                    notificacionesProvider);
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                        content:
                                                            Text('Error: $e')),
                                                  );
                                                }
                                              }
                                            },
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      n.mensaje,
                                      style: TextStyle(
                                        color: _kSub,
                                        fontSize: 13,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Page 1: Datos básicos ─────────────────────────────────────────────────
  Widget _page1() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(children: [
          _card(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _field('NOMBRE DEL NIÑO', 'Ej: Mateo García', _nameCtrl),
                const SizedBox(height: 16),
                _label('FECHA DE NACIMIENTO'),
                InkWell(
                  onTap: _pickDate,
                  child: IgnorePointer(
                      child: TextFormField(
                    controller: _dateCtrl,
                    decoration:
                        _dec('Seleccionar fecha', icon: Icons.calendar_today),
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600, color: _kText),
                  )),
                ),
                const SizedBox(height: 16),
                _field('DIAGNÓSTICO PREVIO DE TDAH (OPCIONAL)',
                    'Ej: TDAH diagnosticado por especialista', _diagCtrl),
                const SizedBox(height: 8),
                Text(
                  'Registro opcional del diagnóstico ya realizado por un profesional. Aquí no se hace ningún diagnóstico automático.',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: _kSub, height: 1.4),
                ),
              ])),
        ]),
      );

  // ── Page 2: Perfil de aprendizaje ─────────────────────────────────────────
  Widget _page2() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(children: [
          _card(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _choice(
                    'NIVEL DE ATENCIÓN / CONCENTRACIÓN',
                    ['Bajo', 'Moderado', 'Alto'],
                    _atencion,
                    (v) => setState(() => _atencion = v)),
                const SizedBox(height: 20),
                _multi(
                    'FORMA EN QUE APRENDE MEJOR',
                    [
                      'Visual (imágenes, demos, esquemas)',
                      'Auditivo (explicaciones y lectura en voz alta)',
                      'Práctico (manipular y experimentar)',
                      'Lectura y escritura',
                      'Con apoyo de otra persona'
                    ],
                    _formaAprende),
                const SizedBox(height: 20),
                _editableRows(
                  label: 'ACTIVIDADES QUE LE RESULTAN DIFÍCILES',
                  hint: 'Ej: escribir textos, problemas de lectura, matemáticas',
                  controller: _actDificilesCtrl,
                  rows: _actDificiles,
                  onAdd: () => _addRow(_actDificiles, _actDificilesCtrl),
                  onRemove: (row) => _removeRow(_actDificiles, row),
                ),
                const SizedBox(height: 20),
                _choice(
                    'CAPACIDAD PARA SEGUIR INSTRUCCIONES',
                    [
                      'Necesita apoyo paso a paso',
                      'Sigue instrucciones simples',
                      'Sigue instrucciones de varias pasos',
                      'Le cuesta seguir instrucciones'
                    ],
                    _instrucciones,
                    (v) => setState(() => _instrucciones = v)),
              ])),
        ]),
      );

  // ── Page 3: Entorno y aprendizaje ─────────────────────────────────────────
  Widget _page3() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(children: [
          _card(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _multi(
                    'PRINCIPALES DISTRACTORES',
                    [
                      'Ruidos',
                      'Pantallas o televisión',
                      'Movimiento de otras personas',
                      'Conversaciones alrededor',
                      'Teléfono o tablet',
                      'Temperatura o luces'
                    ],
                    _distractores),
                const SizedBox(height: 20),
                _multi(
                    'FACTORES QUE DIFICULTAN SU CONCENTRACIÓN',
                    [
                      'Poco sueño',
                      'Cansancio',
                      'Hambre',
                      'Ansiedad o preocupaciones',
                      'Demasiados estímulos',
                      'Falta de rutina'
                    ],
                    _factores),
                const SizedBox(height: 20),
                _choice(
                    'LUGAR HABITUAL DE ESTUDIO',
                    [
                      'Escritorio o mesa en casa',
                      'Su habitación',
                      'Comedor o sala',
                      'Biblioteca',
                      'Otro lugar'
                    ],
                    _lugarEstudio,
                    (v) => setState(() => _lugarEstudio = v)),
                const SizedBox(height: 20),
                _editableRows(
                  label: 'RUTINAS DE ESTUDIO',
                  hint: 'Ej: 20 minutos de tarea y 5 minutos de descanso',
                  controller: _rutinaCtrl,
                  rows: _rutinas,
                  onAdd: () => _addRow(_rutinas, _rutinaCtrl),
                  onRemove: (row) => _removeRow(_rutinas, row),
                ),
                const SizedBox(height: 20),
                _choice(
                    'NECESIDAD DE PAUSAS DURANTE LAS ACTIVIDADES',
                    [
                      'Sí, con frecuencia',
                      'Sí, de forma ocasional',
                      'No necesita pausas'
                    ],
                    _pausas,
                    (v) => setState(() => _pausas = v)),
              ])),
        ]),
      );

  // ── Page 4: Intereses y resumen ───────────────────────────────────────────
  Widget _page4() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(children: [
          _card(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _multi(
                    'INTERESES PRINCIPALES',
                    [
                      'Dinosaurios',
                      'Trenes',
                      'Espacio',
                      'Geometría',
                      'Números',
                      'Música',
                      'Animales'
                    ],
                    _int),
                const SizedBox(height: 24),
                _editableRows(
                  label: 'ACTIVIDADES QUE LO MOTIVAN',
                  hint: 'Ej: juegos de mesa, pintar, deporte, música',
                  controller: _motivanCtrl,
                  rows: _motivan,
                  onAdd: () => _addRow(_motivan, _motivanCtrl),
                  onRemove: (row) => _removeRow(_motivan, row),
                ),
                const SizedBox(height: 20),
                _editableRows(
                  label: 'ESTRATEGIAS QUE UTILIZAS ACTUALMENTE (PADRE/TUTOR)',
                  hint: 'Ej: horario fijo, temporizador, instrucciones de una en una',
                  controller: _estrategiasCtrl,
                  rows: _estrategias,
                  onAdd: () => _addRow(_estrategias, _estrategiasCtrl),
                  onRemove: (row) => _removeRow(_estrategias, row),
                ),
                const SizedBox(height: 24),
                _label('RESUMEN DEL PERFIL DE APRENDIZAJE'),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F5FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _summaryRow(
                          'Nombre:',
                          _nameCtrl.text.trim().isEmpty
                              ? '—'
                              : _nameCtrl.text.trim()),
                      const Divider(color: Color(0xFFC8E9F7), height: 16),
                      _summaryRow('Fecha nac.:',
                          _dateCtrl.text.isEmpty ? '—' : _dateCtrl.text),
                      const Divider(color: Color(0xFFC8E9F7), height: 16),
                      _summaryRow(
                          'Diagnóstico:',
                          _diagCtrl.text.trim().isEmpty
                              ? 'No especificado'
                              : _diagCtrl.text.trim()),
                      const Divider(color: Color(0xFFC8E9F7), height: 16),
                      _summaryRow('Atención:', _atencion),
                      const Divider(color: Color(0xFFC8E9F7), height: 16),
                      _summaryRow(
                          'Aprende mejor con:',
                          _formaAprende.isEmpty
                              ? 'Sin preferencia registrada'
                              : _formaAprende.join(', ')),
                      const Divider(color: Color(0xFFC8E9F7), height: 16),
                      _summaryRow('Lugar de estudio:', _lugarEstudio),
                      const Divider(color: Color(0xFFC8E9F7), height: 16),
                      _summaryRow(
                          'Intereses:',
                          _int.isEmpty
                              ? 'Ninguno seleccionado'
                              : _int.join(', ')),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F5FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.info_outline,
                                  color: Color(0xFF4E56D9), size: 16),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                              'Al registrar, el perfil de aprendizaje quedará guardado para generar recomendaciones personalizadas para ti.',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF2E34A8),
                                  fontWeight: FontWeight.w500,
                                  height: 1.3),
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFC8E9F7)),
                        ),
                        child: CheckboxListTile(
                          value: _acceptedPrivacyConsent,
                          onChanged: (value) => setState(
                            () => _acceptedPrivacyConsent = value ?? false,
                          ),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: _kP,
                          title: Text(
                            'Consentimiento informado',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              color: _kText,
                            ),
                          ),
                          subtitle: Text(
                            'Confirmo el tratamiento de datos sensibles del nino conforme a la Ley N. 29733 y entiendo que SendaIA es una herramienta de apoyo al aprendizaje, no un diagnostico.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: _kSub,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ])),
        ]),
      );

  // ── Widget helpers ────────────────────────────────────────────────────────
  Widget _card({required Widget child, Color? backgroundColor}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: backgroundColor ?? _kSurf,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kBdr.withOpacity(0.5), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]),
        child: child,
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFB08C68),
                letterSpacing: 0.8)),
      );

  InputDecoration _dec(String hint, {IconData? icon}) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: icon != null ? Icon(icon, color: _kA, size: 20) : null,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _kBdr.withOpacity(0.5), width: 1.0)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _kBdr.withOpacity(0.5), width: 1.0)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _kA, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.plusJakartaSans(
            color: _kSub.withOpacity(0.4),
            fontSize: 14,
            fontWeight: FontWeight.normal),
      );

  Widget _field(String label, String hint, TextEditingController ctrl) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          TextFormField(
              controller: ctrl,
              decoration: _dec(hint),
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600, color: _kText)),
        ],
      );

  Widget _editableRows({
    required String label,
    required String hint,
    required TextEditingController controller,
    required List<String> rows,
    required VoidCallback onAdd,
    required ValueChanged<String> onRemove,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 3,
                  decoration: _dec(hint),
                  style:
                      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kA,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Icon(Icons.add, size: 20),
                ),
              ),
            ],
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 10),
            Column(
              children: rows
                  .map(
                    (row) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBdr.withOpacity(0.6)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              row,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                color: _kText,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Quitar',
                            onPressed: () => onRemove(row),
                            icon:
                                const Icon(Icons.close, size: 18, color: _kSub),
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      );

  Widget _choice(String label, List<String> opts, String current,
          ValueChanged<String> onChanged) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: opts.map((o) {
                final sel = o == current;
                return ChoiceChip(
                  label: Text(o),
                  selected: sel,
                  showCheckmark: false,
                  avatar: sel
                      ? const Icon(Icons.check, size: 16, color: _kText)
                      : null,
                  onSelected: (v) {
                    if (v) onChanged(o);
                  },
                  selectedColor: _kA,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                          color: sel ? _kA : _kBdr.withOpacity(0.5),
                          width: 1.0)),
                  labelStyle: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600, fontSize: 13, color: _kText),
                );
              }).toList()),
        ],
      );

  Widget _multi(String label, List<String> opts, Set<String> current) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: opts.map((o) {
                final sel = current.contains(o);
                return FilterChip(
                  label: Text(o),
                  selected: sel,
                  showCheckmark: false,
                  avatar: sel
                      ? const Icon(Icons.check, size: 16, color: _kText)
                      : null,
                  onSelected: (_) => _tog(current, o),
                  selectedColor: _kA,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                          color: sel ? _kA : _kBdr.withOpacity(0.5),
                          width: 1.0)),
                  labelStyle: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600, fontSize: 13, color: _kText),
                );
              }).toList()),
        ],
      );

  Widget _summaryRow(String key, String val) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(key,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w500, color: _kSub)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(val,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _kText)),
            ),
          ],
        ),
      );
}

// ── Status badge definition ──────────────────────────────────────────────────
class _StatusBadgeInfo {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;

  const _StatusBadgeInfo({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
  });
}

_StatusBadgeInfo _getStatusBadgeInfo(String estado) {
  return switch (estado) {
    'plan_activo' => const _StatusBadgeInfo(
        icon: Icons.rocket_launch_outlined,
        label: 'Perfil de aprendizaje activo',
        bgColor: Color(0xFFF5F0FF),
        borderColor: Color(0xFFD6D0FF),
        textColor: Color(0xFF3F47C9),
      ),
    'listo_para_plan' => const _StatusBadgeInfo(
        icon: Icons.check_circle_outline,
        label: 'Perfil de aprendizaje completo',
        bgColor: Color(0xFFEFF6FF),
        borderColor: Color(0xFFBFDBFE),
        textColor: Color(0xFF1D4ED8),
      ),
    'vinculado_terapeuta' => const _StatusBadgeInfo(
        icon: Icons.people_outline,
        label: 'Perfil de aprendizaje registrado',
        bgColor: Color(0xFFFFFBEB),
        borderColor: Color(0xFFFDE68A),
        textColor: Color(0xFFB45309),
      ),
    'perfil_clinico_incompleto' => const _StatusBadgeInfo(
        icon: Icons.warning_amber_outlined,
        label: 'Completando perfil',
        bgColor: Color(0xFFFEF2F2),
        borderColor: Color(0xFFFEE2E2),
        textColor: Color(0xFFDC2626),
      ),
    _ => const _StatusBadgeInfo(
        icon: Icons.check_circle_outline,
        label: 'Perfil de aprendizaje registrado',
        bgColor: Color(0xFFEFF5FA),
        borderColor: Color(0xFFD5E3F0),
        textColor: Color(0xFF4A688C),
      ),
  };
}

// ── Patient status card ───────────────────────────────────────────────────────
String _percent(double value) => '${(value * 100).clamp(0, 100).round()}%';

class _FamilyMetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _FamilyMetricPill({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = _kA,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBdr.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent == _kA ? _kText : accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _kText,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _kSub,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProgressTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBdr.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kSub),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _kText,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _kSub,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientCard extends ConsumerWidget {
  final PacienteDashboard p;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _PatientCard({
    required this.p,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badge = _getStatusBadgeInfo(p.estadoClinico);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBdr.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _kA.withValues(alpha: 0.4),
            child: Text((p.nombre.isNotEmpty ? p.nombre[0] : '?').toUpperCase(),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: _kText)),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(p.nombre,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _kText)),
                Text('${p.edad} años · ${p.nivelCognitivo}',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: _kSub)),
              ])),
          IconButton(
            tooltip: 'Editar registro',
            icon: const Icon(Icons.edit_outlined,
                color: Color(0xFF9CA3AF), size: 20),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Eliminar registro',
            icon: Icon(Icons.delete_outline,
                color: Colors.red.shade400, size: 20),
            onPressed: onDelete,
          ),
        ]),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: badge.bgColor,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: badge.borderColor, width: 1.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(badge.icon, size: 14, color: badge.textColor),
                  const SizedBox(width: 6),
                  Text(badge.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: badge.textColor,
                      )),
                ],
              ),
            ),
            const Spacer(),
            if (p.requiereScq && !p.scqCompletado)
              ElevatedButton.icon(
                icon: const Icon(Icons.quiz_outlined, size: 16),
                label: Text("Responder SCQ",
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold, fontSize: 11)),
                onPressed: () {
                  context.push(
                      '/padre/scq/${p.id}?nombre=${Uri.encodeComponent(p.nombre)}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kP,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              )
            else if (p.requiereScq && p.scqCompletado && !p.scqAutorizadoEnvio)
              ElevatedButton.icon(
                icon: const Icon(Icons.send_outlined, size: 16),
                label: Text("Enviar solicitud",
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold, fontSize: 11)),
                onPressed: () async {
                  await ref
                      .read(dashboardServiceProvider)
                      .enviarCasoScqATerapeuta(p.id);
                  ref.invalidate(familiaDashboardProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Solicitud enviada al terapeuta.')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kP,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
        if (p.requiereScq) ...[
          const SizedBox(height: 10),
          Text(
            p.scqCompletado
                ? 'SCQ: ${p.scqNivel ?? 'Sin nivel'} (${p.scqPuntaje ?? 0} puntos)'
                : 'SCQ pendiente antes de enviar al terapeuta.',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: _kSub, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ProgressTile(
                icon: Icons.task_alt_outlined,
                label: 'Cumplimiento',
                value: _percent(p.progreso.cumplimiento),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ProgressTile(
                icon: Icons.trending_up_outlined,
                label: 'Aciertos',
                value: _percent(p.progreso.tasaAciertos),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ProgressTile(
                icon: Icons.event_note_outlined,
                label: 'Sesiones',
                value: '${p.progreso.sesionesCompletadas}',
              ),
            ),
          ],
        ),
        if (p.ultimaSesion != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.history_outlined, size: 14, color: _kSub),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Ultima sesion: ${p.ultimaSesion!.fecha != null ? '${p.ultimaSesion!.fecha!.day}/${p.ultimaSesion!.fecha!.month}/${p.ultimaSesion!.fecha!.year}' : 'sin fecha'}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: _kSub,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (p.alertas.isNotEmpty) ...[
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: p.alertas
                .map(
                  (alerta) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_outlined,
                            size: 15, color: _kP),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            alerta,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: _kText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        if (p.recomendacionesActivas.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBdr.withValues(alpha: 0.7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 16, color: Color(0xFFB08C68)),
                    const SizedBox(width: 7),
                    Text(
                      'Recomendaciones activas',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: _kText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...p.recomendacionesActivas.map(
                  (recomendacion) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      recomendacion,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        height: 1.35,
                        color: _kSub,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBdr.withValues(alpha: 0.7)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 16, color: Color(0xFFB08C68)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Próximamente podrás recibir recomendaciones personalizadas para apoyar el aprendizaje de tu hijo.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      height: 1.35,
                      color: _kSub,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}
