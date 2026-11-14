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
  const FamilyChatbotScreen({super.key, this.initialNinoId});
  final String? initialNinoId;

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
    _selectedNinoId = widget.initialNinoId;
    // Mensaje de bienvenida inicial
    _messages.add(
      ChatMessage(
        text:
            '¡Hola! Soy tu asistente de orientación educativa.\n\nEstoy aquí para acompañarte en el aprendizaje de tu hijo con TDAH en casa. Puedes consultarme sobre:\n\n'
            '• **Orientación académica:** Estrategias para lectura, escritura y razonamiento.\n'
            '• **Comunicación y motivación:** Manejo de la frustración y refuerzo positivo del esfuerzo.\n'
            '• **Organización del entorno y pausas:** Rutinas, espacio sin distractores y pausas de 15 min.\n\n'
            '¿Sobre qué tema te gustaría conversar hoy?',
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

    // 1. Actividades sugeridas para hoy y catálogo
    if (query.contains('actividad') ||
        query.contains('actividades') ||
        query.contains('sesion') ||
        query.contains('sesión') ||
        query.contains('sugerencia') ||
        query.contains('hoy')) {
      return 'Para acompañar el aprendizaje de **$nombre** en casa hoy:\n\n'
          '1. **Explora la pestaña "Sugerencias":** Encontrarás actividades educativas clasificadas en sus 5 áreas clave:\n'
          '   • Comprensión lectora\n'
          '   • Expresión escrita\n'
          '   • Razonamiento lógico\n'
          '   • Análisis y observación\n'
          '   • Autonomía y organización\n\n'
          '2. **Dos formas de realizarlas:**\n'
          '   • **Hacer con temporizador guiado:** La app cronometra la sesión con pausas y registra los aciertos.\n'
          '   • **Ya la completó en casa:** Si hicieron la tarea juntos en su cuaderno, presiona "Ya la completó en casa" para registrar el tiempo y tus observaciones.\n\n'
          'Todas las actividades guardadas se reflejarán inmediatamente en su **Seguimiento familiar**.';
    }

    // 2. Orientación académica: lectura, escritura, razonamiento, tareas
    if (query.contains('lectura') ||
        query.contains('leer') ||
        query.contains('comprension') ||
        query.contains('comprensión') ||
        query.contains('escrit') ||
        query.contains('redacc') ||
        query.contains('matemat') ||
        query.contains('matemát') ||
        query.contains('calcul') ||
        query.contains('acad')) {
      return 'Aquí tienes pautas de orientación académica para **$nombre**:\n\n'
          '📖 **Comprensión lectora:**\n'
          '• **Lectura compartida:** Lean por turnos (un párrafo tú, uno él). Esto reduce la fatiga visual.\n'
          '• **Preguntas intermedias:** No esperes al final del texto. Pregunta: *"¿Qué crees que pasará ahora?"* al terminar cada escena.\n'
          '• **Guía visual:** Usa una regla o marcapáginas bajo la línea para evitar saltarse renglones.\n\n'
          '✍️ **Expresión escrita:**\n'
          '• **Lluvia de ideas previa:** Antes de redactar, anoten palabras clave o dibujos en pósits de colores y ordénenlos juntos.\n'
          '• **Frases cortas:** Anímalo a escribir una sola idea por oración.\n\n'
          '🔢 **Razonamiento lógico:**\n'
          '• **Apoyo concreto:** Utilicen objetos reales (fichas, monedas, bloques) antes de pasar al papel.\n'
          '• **Subrayado con colores:** Marca de azul los datos numéricos y de rojo la pregunta del problema.';
    }

    // 3. Comunicación y motivación: Frustración, enojo, validación, refuerzo
    if (query.contains('motiv') ||
        query.contains('frustr') ||
        query.contains('enoj') ||
        query.contains('rabia') ||
        query.contains('llor') ||
        query.contains('cansa') ||
        query.contains('bloque') ||
        query.contains('autoestima') ||
        query.contains('comunic')) {
      return 'La frustración y el cansancio son muy frecuentes en niños con TDAH ante tareas prolongadas. Para acompañar a **$nombre**:\n\n'
          '💬 **Validación emocional primero:**\n'
          '• En vez de *"concéntrate"* o *"esto es fácil"*, dile: *"Veo que este ejercicio es difícil y te cansa; es normal sentirse frustrado. Respiremos un minuto juntos"*.\n\n'
          '🌟 **Elogio al esfuerzo y no al resultado:**\n'
          '• Destaca el proceso: *"Noté lo perseverante que fuiste al no rendirte con esa oración"* en vez de *"qué inteligente eres"*.\n\n'
          '⏸️ **Pausa de reinicio activa:**\n'
          '• Si notas señales de bloqueo o enojo, detén la tarea 3 minutos para tomar agua, estirarse o hacer 5 saltos. Volver después de moverse despeja la mente.\n\n'
          '🎯 **Objetivos muy pequeños:**\n'
          '• *"Hagamos solo los primeros 2 ejercicios y revisamos juntos"*. La meta cercana reduce la ansiedad de ver una página llena.';
    }

    // 4. Organización del entorno y pausas: rutinas, Pomodoro, espacio, distractores
    if (query.contains('rutina') ||
        query.contains('rutinas') ||
        query.contains('estudio') ||
        query.contains('tarea') ||
        query.contains('tareas') ||
        query.contains('horario') ||
        query.contains('organiz') ||
        query.contains('pomodoro') ||
        query.contains('tiempo') ||
        query.contains('espacio') ||
        query.contains('distractor') ||
        query.contains('distrae') ||
        query.contains('ambiente')) {
      final distractores = _listaDePerfil(perfil, 'distractores');
      final distractoresTxt = distractores.isNotEmpty
          ? '\n*(Tienes registrados como distractores de $nombre: ${distractores.join(', ').toLowerCase()}.)*'
          : '';

      return 'Para optimizar la organización del entorno de aprendizaje de **$nombre**:\n\n'
          '⏰ **Técnica de bloques cortos (Pomodoro adaptado):**\n'
          '• **15 a 20 minutos de foco:** Los niños con TDAH rinden mucho mejor en periodos breves e intensos.\n'
          '• **3 a 5 minutos de descanso activo:** Moverse, estirarse o hidratarse antes del siguiente bloque.\n'
          '• **Temporizador visible:** Usa el reloj de la app o un cronómetro para que vea el paso del tiempo.\n\n'
          '🧹 **Mesa libre de distractores:**$distractoresTxt\n'
          '• Solo debe estar en la mesa el cuaderno y el lápiz del ejercicio en curso. Guarda juguetes, celular o libros de otra materia.\n\n'
          '📋 **Checklist visual:**\n'
          '• Escribe en una pizarra o papel las 3 tareas del día y permite que **$nombre** marque la casilla con un visto al terminar cada una.';
    }

    // 5. Preguntas generales sobre TDAH
    if (query.contains('que es') ||
        query.contains('qué es') ||
        query.contains('tdah') ||
        query.contains('deficit de atencion') ||
        query.contains('déficit de atención')) {
      return 'El **Trastorno por Déficit de Atención e Hiperactividad (TDAH)** es una condición del neurodesarrollo que involucra las funciones ejecutivas del cerebro, como la atención sostenida, la memoria de trabajo y el control de impulsos.\n\n'
          '**Clave pedagógica para la familia:**\n'
          'No es falta de voluntad ni desobediencia: su cerebro busca estímulos y se agota más rápido con tareas repetitivas o largas. Con entornos ordenados, consignas breves de una en una y pausas activas, su capacidad de aprendizaje florece.';
    }

    // 6. Fallback estructurado en los 3 ejes
    return 'Entiendo tu consulta. Como asistente de orientación para **$nombre**, puedo ayudarte en estos 3 ejes:\n\n'
        '1. 📖 **Orientación académica:** Estrategias para lectura compartida, escritura paso a paso y razonamiento.\n'
        '2. 💬 **Comunicación y motivación:** Cómo elogiar el esfuerzo, validar emociones y frenar la frustración.\n'
        '3. ⏰ **Organización del entorno y pausas:** Rutinas de 15 min (Pomodoro adaptado), mesa sin distractores, checklists y pausas activas.\n\n'
        '¿Sobre cuál de estos aspectos te gustaría que profundicemos?';
  }

  List<String> _listaDePerfil(PacientePerfil? perfil, String clave) {
    final valor = perfil?.perfilSensorial[clave];
    if (valor is List) return valor.map((e) => e.toString()).toList();
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final familyDataAsync = ref.watch(familiaDashboardProvider);
    final pacientes =
        familyDataAsync.valueOrNull?.pacientes ?? const <PacienteDashboard>[];
    final selectedNinoId = _selectedNinoId ??
        (pacientes.isNotEmpty ? pacientes.first.id : null);
    final childQuery = selectedNinoId == null
        ? ''
        : '?nino=${Uri.encodeQueryComponent(selectedNinoId)}';

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
        currentIndex: 4,
        onTap: (index) {
          if (index == 0) {
            context.go('/familia/dashboard$childQuery');
          }
          if (index == 1) {
            context.go('/familia/perfil$childQuery');
          }
          if (index == 2) {
            context.go('/familia/seguimiento$childQuery');
          }
          if (index == 3) {
            final ninoQuery = selectedNinoId == null
                ? ''
                : '?ninoId=${Uri.encodeQueryComponent(selectedNinoId)}';
            context.go('/familia/sugerencias$ninoQuery');
          }
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
        '📖 Orientación académica',
        '¿Cómo apoyar a $ninoNombre en lectura, escritura y tareas?'
      ),
      (
        '💬 Comunicación y motivación',
        '¿Cómo motivar a $ninoNombre y manejar la frustración con las tareas?'
      ),
      (
        '⏰ Organización del entorno y pausas',
        '¿Cómo organizar su tiempo y espacio de estudio con pausas de 15 min?'
      ),
      (
        '🎯 Actividades para hoy',
        '¿Qué actividades me sugieres realizar hoy con $ninoNombre en casa?'
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
