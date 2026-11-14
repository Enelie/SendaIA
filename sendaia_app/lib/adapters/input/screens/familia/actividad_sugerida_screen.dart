import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

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

/// Actividad sugerida en modo guiado: el padre acompaña al niño con el
/// celular, se cronometra la sesión y al terminar se registra en Seguimiento.
class ActividadSugeridaScreen extends ConsumerStatefulWidget {
  final String ninoId;
  final SugerenciaActividad sugerencia;

  const ActividadSugeridaScreen({
    super.key,
    required this.ninoId,
    required this.sugerencia,
  });

  @override
  ConsumerState<ActividadSugeridaScreen> createState() =>
      _ActividadSugeridaScreenState();
}

class _ActividadSugeridaScreenState
    extends ConsumerState<ActividadSugeridaScreen> {
  late final int _totalSegundos;
  late int _restante;
  Timer? _timer;
  bool _corriendo = false;
  bool _iniciada = false;
  bool _guardando = false;
  int _nivelAyuda = 0;
  final TextEditingController _obs = TextEditingController();
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _totalSegundos = widget.sugerencia.duracionSegundos > 0
        ? widget.sugerencia.duracionSegundos
        : 300;
    _restante = _totalSegundos;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _obs.dispose();
    super.dispose();
  }

  int get _transcurrido => _iniciada ? _totalSegundos - _restante : 0;

  String get _tiempoTexto {
    final m = (_restante ~/ 60).toString().padLeft(2, '0');
    final s = (_restante % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _alternarTimer() {
    if (_corriendo) {
      _timer?.cancel();
      setState(() => _corriendo = false);
      return;
    }
    setState(() {
      _corriendo = true;
      _iniciada = true;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_restante <= 1) {
        t.cancel();
        setState(() {
          _restante = 0;
          _corriendo = false;
        });
        return;
      }
      setState(() => _restante -= 1);
    });
  }

  Future<void> _guardar(String estado) async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      await ref.read(seguimientoServiceProvider).registrarActividadFamiliar(
            ninoId: widget.ninoId,
            actividadId: widget.sugerencia.actividadId,
            modalidad: 'guiada_app',
            estado: estado,
            duracionSegundos: _iniciada ? _transcurrido : null,
            nivelAyudaRequerido: _nivelAyuda,
            observaciones: _obs.text,
            clientEventId: _uuid.v4(),
          );
      if (!mounted) return;
      ref.invalidate(seguimientoFamiliarProvider);
      ref.invalidate(familiaDashboardProvider);
      final messenger = ScaffoldMessenger.of(context);
      context.pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            estado == 'completada'
                ? 'Actividad registrada. Ya aparece en Seguimiento y en Inicio.'
                : 'Actividad guardada como interrumpida en Seguimiento.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: _kP,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
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
    final s = widget.sugerencia;
    final progreso = _totalSegundos == 0
        ? 0.0
        : (1 - (_restante / _totalSegundos)).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _kText),
          onPressed: () => context.pop(),
        ),
        title: Text('Actividad guiada',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _kText)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kBdr.withValues(alpha: 0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.nombre,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _kText)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (s.nivelDificultad.isNotEmpty)
                          _chip(s.nivelDificultad, _kA.withValues(alpha: 0.4)),
                        if (s.tipo.isNotEmpty)
                          _chip(s.tipo, _kP.withValues(alpha: 0.2)),
                        _chip('${(_totalSegundos / 60).round()} min',
                            _kBdr.withValues(alpha: 0.5)),
                      ],
                    ),
                    if (s.instrucciones != null &&
                        s.instrucciones!.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text('CÓMO HACERLA',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF5A738E))),
                      const SizedBox(height: 6),
                      Text(s.instrucciones!,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                              color: _kText)),
                    ],
                    if (s.materiales.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Materiales: ${s.materiales.join(', ')}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _kSub)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kBdr.withValues(alpha: 0.6)),
                ),
                child: Column(
                  children: [
                    Text('TIEMPO',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF5A738E))),
                    const SizedBox(height: 6),
                    Text(_tiempoTexto,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: _kText,
                            height: 1.1)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: progreso,
                        minHeight: 8,
                        backgroundColor: _kBg,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(_kP),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _guardando ? null : _alternarTimer,
                        icon: Icon(
                            _corriendo
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 20),
                        label: Text(_corriendo
                            ? 'Pausar'
                            : _iniciada
                                ? 'Continuar'
                                : 'Iniciar actividad'),
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
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kBdr.withValues(alpha: 0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        hintText:
                            'Ej. Se concentró mejor con pausas cortas.',
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
                          borderSide:
                              const BorderSide(color: _kP, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : () => _guardar('completada'),
                  icon: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline, size: 19),
                  label: const Text('Terminamos: registrar actividad'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kP,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _guardando ? null : () => _guardar('interrumpida'),
                  child: Text('No se completó',
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
    );
  }

  Widget _nivelChip(int valor, String texto) {
    final sel = _nivelAyuda == valor;
    return ChoiceChip(
      label: Text(texto),
      selected: sel,
      onSelected: (_) => setState(() => _nivelAyuda = valor),
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

  Widget _chip(String texto, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(texto,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: _kText)),
      );
}
