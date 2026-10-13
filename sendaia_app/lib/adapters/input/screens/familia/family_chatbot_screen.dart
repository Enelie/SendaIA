import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:rimai_app/adapters/input/widgets/rimai_bottom_nav.dart';
import 'package:rimai_app/adapters/input/widgets/rimai_top_bar.dart';
import 'package:rimai_app/core/providers/dashboard_providers.dart';
import 'package:rimai_app/core/providers/pmv2_providers.dart';

const _kPrimary = Color(0xFF5CBF95);
const _kBg = Color(0xFFE9F8FF);
const _kSurface = Color(0xFFF6FEFF);
const _kText = Color(0xFF1E1B16);
const _kSubtext = Color(0xFF58423B);

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class FamilyChatbotScreen extends ConsumerStatefulWidget {
  const FamilyChatbotScreen({super.key});

  @override
  ConsumerState<FamilyChatbotScreen> createState() =>
      _FamilyChatbotScreenState();
}

class _FamilyChatbotScreenState extends ConsumerState<FamilyChatbotScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedNinoId;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Mensaje de bienvenida inicial
    _messages.add(
      ChatMessage(
        text:
            '¡Hola! Soy tu asistente de IA.\n\nEstoy aquí para ayudarte a apoyar el aprendizaje de tu hijo con TDAH. Puedes consultarme sobre estrategias de estudio, organización de rutinas, concentración, motivación y actividades para realizar en casa.\n\n¿En qué te gustaría recibir ayuda hoy?',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(String text, {PacientePerfil? perfil, PlanData? plan}) {
    if (text.trim().isEmpty) return;
    _controller.clear();

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isTyping = true;
    });
    _scrollToBottom();

    // Simular retraso del chatbot local (< 1.5s)
    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final reply = _generateResponse(text, perfil: perfil, plan: plan);
      setState(() {
        _isTyping = false;
        _messages.add(
          ChatMessage(
            text: reply,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    });
  }

  String _generateResponse(String text,
      {PacientePerfil? perfil, PlanData? plan}) {
    final query = text.toLowerCase().trim();
    final nombre = perfil?.nombre ?? 'tu niño';

    // 1. Actividades sugeridas para hoy
    if (query.contains('actividad') ||
        query.contains('actividades') ||
        query.contains('sesion') ||
        query.contains('sesión') ||
        query.contains('plan') ||
        query.contains('hoy')) {
      if (plan == null || plan.actividades.isEmpty) {
        return 'Todavía no tienes actividades sugeridas para $nombre. Pronto podrás recibir recomendaciones personalizadas para apoyar su aprendizaje; mientras tanto, puedes preguntarme por estrategias de estudio, organización o concentración.';
      }

      final buffer = StringBuffer();
      buffer.writeln(
          'Para el día de hoy de **$nombre** te sugiero acompañar estas actividades en casa:');
      buffer.writeln();
      for (var i = 0; i < plan.actividades.length; i++) {
        final act = plan.actividades[i];
        final tipo = act.requiereAcompanamiento
            ? 'Acompañada (requiere tu apoyo)'
            : 'Autónoma (el niño puede hacerla solo)';
        buffer.writeln('${i + 1}. **${act.nombre}** (${act.nivelDificultad}):');
        buffer.writeln('   - *Tipo:* $tipo');
        buffer.writeln(
            '   - *Instrucciones:* ${act.instrucciones ?? "Sin instrucciones específicas."}');
        if (i < plan.actividades.length - 1) buffer.writeln();
      }
      buffer.writeln();
      buffer.writeln(
          '¿Tienes alguna duda sobre cómo acompañar alguna de ellas en casa?');
      return buffer.toString();
    }

    // 2. Rutinas y organización del estudio
    if (query.contains('rutina') ||
        query.contains('rutinas') ||
        query.contains('estudio') ||
        query.contains('tarea') ||
        query.contains('tareas') ||
        query.contains('horario') ||
        query.contains('organiz')) {
      final rutinas = _rutinasDeEstudio(perfil);
      if (rutinas.isEmpty) {
        return 'Aún no has registrado rutinas de estudio para $nombre.\n\n**Consejo general de organización:**\n1. **Horario fijo:** Mantener el mismo horario de estudio cada día.\n2. **Bloques cortos:** Dividir la tarea en tramos de 15 a 20 minutos con una pausa breve.\n3. **Instrucciones de una en una:** Dar una indicación y esperar a que la complete antes de la siguiente.\n\nPuedes registrar sus rutinas de estudio en el botón "Editar registro" de su tarjeta en el Inicio.';
      }

      final buffer = StringBuffer();
      buffer.writeln(
          'Aquí tienes las rutinas de estudio que has registrado para **$nombre**:');
      for (final r in rutinas) {
        buffer.writeln('• $r');
      }
      buffer.writeln();
      buffer.writeln(
          '¿Te gustaría que te sugiera cómo mantener estas rutinas en los días de más carga?');
      return buffer.toString();
    }

    // 3. Preguntas generales sobre TDAH
    if (query.contains('que es') ||
        query.contains('qué es') ||
        query.contains('tdah') ||
        query.contains('deficit de atencion') ||
        query.contains('déficit de atención')) {
      return 'El **Trastorno por Déficit de Atención e Hiperactividad (TDAH)** es una condición del neurodesarrollo que puede influir en la atención, la organización y el control de impulsos. Puede presentarse principalmente con dificultades de atención, con hiperactividad e impulsividad, o con una combinación de ambas.\n\n'
          'Cada niño lo vive de manera distinta. En casa y en la escuela, las rutinas claras, las pausas y el reconocimiento de sus avances ayudan mucho a su aprendizaje.';
    }

    // 4. Concentración, impulsividad y organización
    if (query.contains('concentr') ||
        query.contains('impulsiv') ||
        query.contains('hiperactiv') ||
        query.contains('organizar')) {
      return 'Para acompañar a un niño con TDAH cuando le cuesta concentrarse u organizarse, puede ayudar dividir las tareas en pasos breves, usar instrucciones claras de una en una y establecer rutinas previsibles. También conviene reconocer sus avances y acordar pausas cortas antes de que la atención caiga.\n\n'
          'Si quieres, puedo sugerirte estrategias concretas para la hora de estudio en casa.';
    }

    // 5. Distractores y ambiente de estudio
    if (query.contains('distractor') ||
        query.contains('distrae') ||
        query.contains('distraer') ||
        query.contains('ruido') ||
        query.contains('ruidos') ||
        query.contains('sensorial')) {
      final distractores = _listaDePerfil(perfil, 'distractores');
      final conocidos = distractores.isNotEmpty
          ? '\n\nPara **$nombre** tienes registrados estos distractores: ${distractores.join(', ').toLowerCase()}.'
          : '';

      return 'Los distractores reducen el tiempo en que el niño puede mantenerse enfocado.$conocidos\n\n'
          '**Consejos prácticos:**\n'
          '1. **Mesa preparada:** Deja solo lo necesario sobre la mesa y guarda el resto.\n'
          '2. **Sin pantallas cerca:** Alejar televisión, teléfono y tablet del lugar de estudio.\n'
          '3. **Pausa antes de empezar:** Un descanso corto antes de la tarea ayuda a entrar en foco.';
    }

    // 6. Fallback amigable
    return 'Entiendo tu consulta. Soy tu asistente de apoyo para el aprendizaje de **$nombre**.\n\nPuedes preguntarme sobre:\n'
        '• Estrategias de estudio (ej. "*¿Cómo organizar su tiempo de estudio?*").\n'
        '• Concentración y motivación (ej. "*¿Cómo mejorar su concentración?*").\n'
        '• Distractores y ambiente de estudio (ej. "*¿Qué suele distraerlo más?*").\n'
        '• Información general sobre el TDAH (ej. "*¿Qué es el TDAH?*").\n\n'
        '¿En qué te gustaría recibir ayuda hoy?';
  }

  List<String> _rutinasDeEstudio(PacientePerfil? perfil) {
    final guardadas = _listaDePerfil(perfil, 'rutinas_estudio');
    if (guardadas.isNotEmpty) return guardadas;
    return perfil?.rutinasRegulacion ?? [];
  }

  List<String> _listaDePerfil(PacientePerfil? perfil, String clave) {
    final valor = perfil?.perfilSensorial[clave];
    if (valor is List) return valor.map((e) => e.toString()).toList();
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final familyDataAsync = ref.watch(familiaDashboardProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: const RimAITopBar(
        title: 'Asistente IA Familiar',
        leadingIcon: Icons.forum_rounded,
        iconColor: _kPrimary,
      ),
      body: familyDataAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _kPrimary),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudo cargar la información familiar: $err',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (data) {
          final pacientes = data.pacientes;

          // Seleccionar automáticamente el primer niño si no hay selección
          if (_selectedNinoId == null && pacientes.isNotEmpty) {
            _selectedNinoId = pacientes.first.id;
          }

          final selectedNino = pacientes.isEmpty
              ? null
              : pacientes.firstWhere((p) => p.id == _selectedNinoId,
                  orElse: () => pacientes.first);

          return Consumer(
            builder: (context, ref, child) {
              // Cargar dinámicamente el perfil del paciente y su plan
              final perfilAsync = _selectedNinoId != null
                  ? ref.watch(perfilPacienteProvider(_selectedNinoId!))
                  : null;
              final planAsync = _selectedNinoId != null
                  ? ref.watch(planActivoProvider(_selectedNinoId!))
                  : null;

              final PacientePerfil? perfil = perfilAsync?.valueOrNull;
              final PlanData? plan = planAsync?.valueOrNull;

              return Column(
                children: [
                  // Banner de Selector de Niño
                  if (pacientes.isNotEmpty)
                    Container(
                      color: _kSurface,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.child_care_rounded,
                              color: _kPrimary, size: 20),
                          const SizedBox(width: 10),
                          const Text(
                            'Consultando sobre:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: _kSubtext),
                          ),
                          const Spacer(),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedNinoId,
                              dropdownColor: _kSurface,
                              icon: const Icon(Icons.arrow_drop_down,
                                  color: _kPrimary),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _kPrimary,
                                fontSize: 15,
                              ),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedNinoId = val;
                                    // Agregar mensaje informando el cambio de contexto
                                    final pName = pacientes
                                        .firstWhere((p) => p.id == val)
                                        .nombre;
                                    _messages.add(
                                      ChatMessage(
                                        text:
                                            'Cambiando el asistente al contexto de **$pName**. Ahora mis respuestas considerarán el perfil de aprendizaje registrado.',
                                        isUser: false,
                                        timestamp: DateTime.now(),
                                      ),
                                    );
                                  });
                                  _scrollToBottom();
                                }
                              },
                              items: pacientes.map((p) {
                                return DropdownMenuItem<String>(
                                  value: p.id,
                                  child: Text(p.nombre),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Caja de Mensajes
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(24),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isTyping) {
                          return _buildTypingIndicator();
                        }
                        final message = _messages[index];
                        return _buildMessageBubble(message);
                      },
                    ),
                  ),

                  // Fichas de Sugerencia rápidas
                  if (_messages.length <= 2 && selectedNino != null)
                    _buildSuggestionChips(selectedNino.nombre, perfil, plan),

                  // Campo de Entrada de Texto
                  _buildInputArea(perfil, plan),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: RimAIBottomNav(
        currentIndex: 1, // Chatbot IA
        onTap: (index) {
          if (index == 0) {
            context.go('/familia/dashboard');
          }
        },
        items: [
          BottomNavItem(icon: Icons.home_rounded, label: 'Inicio'),
          BottomNavItem(icon: Icons.forum_rounded, label: 'Asistente IA'),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: msg.isUser ? _kPrimary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: msg.isUser ? const Radius.circular(20) : Radius.zero,
            bottomRight: msg.isUser ? Radius.zero : const Radius.circular(20),
          ),
          border: msg.isUser
              ? null
              : Border.all(color: _kSubtext.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Procesa texto simple con soporte de negritas básicas **
            _buildMarkdownText(msg.text, msg.isUser),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 10,
                  color: msg.isUser
                      ? Colors.white.withValues(alpha: 0.6)
                      : _kSubtext.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdownText(String rawText, bool isUser) {
    final style = GoogleFonts.plusJakartaSans(
      fontSize: 14.5,
      height: 1.45,
      color: isUser ? Colors.white : _kText,
    );

    final List<InlineSpan> spans = [];
    final reg = RegExp(r'\*\*(.*?)\*\*');
    int start = 0;

    for (final match in reg.allMatches(rawText)) {
      if (match.start > start) {
        spans.add(TextSpan(text: rawText.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      start = match.end;
    }

    if (start < rawText.length) {
      spans.add(TextSpan(text: rawText.substring(start)));
    }

    return RichText(
      text: TextSpan(
        style: style,
        children: spans,
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.zero,
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(color: _kSubtext.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 5),
            _buildDot(1),
            const SizedBox(width: 5),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int delayIndex) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: _kPrimary,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildSuggestionChips(
      String ninoNombre, PacientePerfil? perfil, PlanData? plan) {
    final chips = [
      (
        '📚 ¿Cómo organizar su estudio?',
        '¿Cómo organizar el tiempo de estudio de $ninoNombre?'
      ),
      (
        '🎯 ¿Cómo mejorar su concentración?',
        '¿Cómo mejorar la concentración de $ninoNombre?'
      ),
      (
        '📘 ¿Qué es el TDAH y cómo influye?',
        '¿Qué es el TDAH y cuáles son sus características principales?'
      ),
      (
        '💡 ¿Qué suele distraerlo más?',
        '¿Qué suele distraer más a $ninoNombre?'
      ),
    ];

    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: chips.length,
        itemBuilder: (context, index) {
          final item = chips[index];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ActionChip(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              side: const BorderSide(color: _kPrimary, width: 1.0),
              label: Text(
                item.$1,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: _kPrimary,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              onPressed: () => _handleSend(item.$2, perfil: perfil, plan: plan),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea(PacientePerfil? perfil, PlanData? plan) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      decoration: BoxDecoration(
        color: _kBg,
        border: Border(
          top: BorderSide(
            color: _kSubtext.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                style: GoogleFonts.plusJakartaSans(color: _kText, fontSize: 15),
                decoration: InputDecoration(
                    hintText: 'Pregúntame sobre estudio, concentración o TDAH...',
                  hintStyle: TextStyle(
                    color: _kSubtext.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  border: InputBorder.none,
                ),
                onSubmitted: (val) =>
                    _handleSend(val, perfil: perfil, plan: plan),
              ),
            ),
          ),
          const SizedBox(width: 14),
          IconButton.filled(
            onPressed: () =>
                _handleSend(_controller.text, perfil: perfil, plan: plan),
            icon: const Icon(Icons.send_rounded),
            style: IconButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }
}
