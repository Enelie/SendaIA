import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RimAIFooter extends StatelessWidget {
  const RimAIFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDot(opacity: 1.0),
              const SizedBox(width: 6),
              _buildDot(opacity: 0.6),
              const SizedBox(width: 6),
              _buildDot(opacity: 0.3),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'SENDAIA © 2026',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color.fromARGB(255, 132, 140, 158).withValues(alpha: 0.6),
              letterSpacing: 2.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot({required double opacity}) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFBAB0FF).withValues(alpha: opacity),
      ),
    );
  }
}
