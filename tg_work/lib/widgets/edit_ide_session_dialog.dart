import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/ide_session_log.dart';
import '../services/firestore_service.dart';
import '../utils/work_timer_format.dart';

/// Editar duração e dia de uma sessão IDE (automática ou manual).
Future<bool> showEditIdeSessionDialog(
  BuildContext context, {
  required FirestoreService service,
  required String userId,
  required IdeSessionLog session,
  String projectLabel = '',
}) async {
  if (userId.isEmpty || session.id.isEmpty) return false;

  final totalMin = session.durationSeconds > 0
      ? (session.durationSeconds / 60).round()
      : 0;
  final hoursCtrl = TextEditingController(text: '${totalMin ~/ 60}');
  final minsCtrl = TextEditingController(text: '${totalMin % 60}');
  DateTime day = DateTime(
    session.closedAt.year,
    session.closedAt.month,
    session.closedAt.day,
  );
  var saving = false;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        Future<void> pickDay() async {
          final picked = await showDatePicker(
            context: ctx,
            initialDate: day,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 1)),
          );
          if (picked != null) setLocal(() => day = picked);
        }

        Future<void> save() async {
          final h = int.tryParse(hoursCtrl.text.trim()) ?? 0;
          final m = int.tryParse(minsCtrl.text.trim()) ?? 0;
          final secs = h * 3600 + m * 60;
          if (secs <= 0) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Indica uma duração maior que 0.')),
            );
            return;
          }
          setLocal(() => saving = true);
          try {
            await service.updateIdeSessionTimes(
              userId: userId,
              sessionId: session.id,
              workDay: day,
              durationSeconds: secs,
            );
            if (ctx.mounted) Navigator.of(ctx).pop(true);
          } catch (e) {
            setLocal(() => saving = false);
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('Falha ao gravar: $e')),
              );
            }
          }
        }

        final label = projectLabel.trim().isNotEmpty
            ? projectLabel.trim()
            : (session.workspaceName.trim().isNotEmpty
                ? session.workspaceName.trim()
                : session.id);

        return AlertDialog(
          title: const Text('Editar tempo da sessão'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Actual: ${formatWorkDurationSeconds(session.durationSeconds)}'
                  '${session.isManual ? ' · manual' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: saving ? null : pickDay,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Dia',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(DateFormat('dd/MM/yyyy').format(day)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hoursCtrl,
                        enabled: !saving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Horas',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: minsCtrl,
                        enabled: !saving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Minutos',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Isto actualiza o relatório e o Kanban da Agenda IDE.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: saving ? null : save,
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        );
      },
    ),
  );

  hoursCtrl.dispose();
  minsCtrl.dispose();
  return ok == true;
}
