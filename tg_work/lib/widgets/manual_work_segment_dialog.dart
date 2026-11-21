import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/work_target_kind.dart';
import '../services/firestore_service.dart';

/// Diálogo para introduzir tempo manual no relógio (projeto / tema / desenvolvimento).
Future<bool> showManualWorkSegmentDialog(
  BuildContext context, {
  required FirestoreService service,
  required String userId,
  required WorkTargetKind kind,
  required String targetId,
  required String projectId,
  required String targetName,
}) async {
  if (userId.isEmpty || targetId.isEmpty || projectId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Precisas de estar autenticado.')),
    );
    return false;
  }

  DateTime day = DateTime.now();
  final hoursCtrl = TextEditingController(text: '1');
  final minsCtrl = TextEditingController(text: '0');
  final descCtrl = TextEditingController();
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
            await service.addManualWorkSegment(
              userId: userId,
              kind: kind,
              targetId: targetId,
              projectId: projectId,
              workDay: day,
              durationSeconds: secs,
              description: descCtrl.text,
            );
            if (ctx.mounted) Navigator.of(ctx).pop(true);
          } catch (e) {
            setLocal(() => saving = false);
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('Falha ao gravar tempo: $e')),
              );
            }
          }
        }

        return AlertDialog(
          title: const Text('Introduzir tempo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${kind.label}: $targetName',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
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
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  enabled: !saving,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descrição da tarefa',
                    hintText: 'Ex.: reunião de arranque',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'O tempo entra no total deste ${kind.label} e na linha de tempo do relógio.',
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
                  : const Text('Gravar'),
            ),
          ],
        );
      },
    ),
  );

  hoursCtrl.dispose();
  minsCtrl.dispose();
  descCtrl.dispose();
  return ok == true;
}
