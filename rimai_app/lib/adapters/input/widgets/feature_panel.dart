import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RimAIFeaturePanel extends StatelessWidget {
  const RimAIFeaturePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 460),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FEFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC8E9F7).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Círculo decorativo inferior-derecha (borroso y suave)
          Positioned(
            bottom: -40,
            right: -40,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color.fromRGBO(186, 176, 255, 0.2),
              ),
            ),
          ),
          // Círculo decorativo superior-derecha
          Positioned(
            top: -30,
            right: 20,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF0F1FF).withValues(alpha: 0.3),
              ),
            ),
          ),
          // Contenido principal
          Padding(
            padding:
                const EdgeInsets.all(48), // Padding superior de la directiva
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu espacio,\ntu IA',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFBAB0FF),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 24),
                _buildFeatureRow(
                  circleBg: const Color(0xFFF0F1FF),
                  icon: Icons.psychology,
                  iconColor: const Color(0xFF5A61E6),
                  label: 'IA diseñada para el bienestar',
                ),
                const SizedBox(height: 24),
                _buildFeatureRow(
                  circleBg: const Color(0xFFD8F3FF),
                  icon: Icons.child_care,
                  iconColor: const Color.fromARGB(255, 80, 78, 99),
                  label: 'Entornos sensoriales adaptativos',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required Color circleBg,
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: circleBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF63524E),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
