import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/theme_item.dart';
import '../models/development.dart';

Color projectStatusColor(ProjectStatus status) {
  switch (status) {
    case ProjectStatus.exequivel:
      return Colors.green;
    case ProjectStatus.naoExequivel:
      return Colors.red;
  }
}

Color themeStatusColor(ThemeStatus status) {
  switch (status) {
    case ThemeStatus.emEstudo:
      return Colors.blue;
    case ThemeStatus.emAndamento:
      return Colors.orange;
    case ThemeStatus.emAvaliacao:
      return Colors.purple;
    case ThemeStatus.feito:
      return Colors.green;
  }
}

Color devStatusColor(DevelopmentStatus status) {
  switch (status) {
    case DevelopmentStatus.emAndamento:
      return Colors.orange;
    case DevelopmentStatus.parado:
      return Colors.red;
    case DevelopmentStatus.bom:
      return Colors.lightGreen;
    case DevelopmentStatus.podeMelhorar:
      return Colors.amber;
    case DevelopmentStatus.feito:
      return Colors.green;
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
