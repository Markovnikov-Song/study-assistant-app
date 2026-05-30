import 'package:flutter/material.dart';

/// 软件工坊 / 工坊生成物右上角「DIY」角标
class DiyCornerBadge extends StatelessWidget {
  const DiyCornerBadge({super.key});

  static const _gradient = LinearGradient(
    colors: [Color(0xFF0F766E), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Text(
        'DIY',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          height: 1.1,
        ),
      ),
    );
  }
}
