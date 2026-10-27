import 'package:flutter/material.dart';

import '../models/project.dart';
import 'status_badge.dart';

/// Escolhe um estado de projeto (lista / detalhe / atalho).
Future<ProjectStatus?> showProjectStatusPicker(
  BuildContext context, {
  required ProjectStatus current,
}) {
  return showModalBottomSheet<ProjectStatus>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Mudar estado',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
            ),
            ...ProjectStatus.values.map((s) {
              final selected = s == current;
              return ListTile(
                leading: Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: projectStatusColor(s),
                ),
                title: Text(s.label),
                trailing: StatusBadge(
                  label: s.label,
                  color: projectStatusColor(s),
                ),
                onTap: () => Navigator.pop(ctx, s),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
