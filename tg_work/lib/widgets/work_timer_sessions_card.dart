import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/active_work_clock.dart';
import '../models/work_target_kind.dart';
import '../services/firestore_service.dart';
import '../utils/work_segment_timeline.dart';
import '../utils/work_timer_format.dart';
import 'manual_work_segment_dialog.dart';

/// Linha de tempo dos segmentos do relógio manual (como as sessões IDE).
class WorkTimerSessionsCard extends StatelessWidget {
  final FirestoreService service;
  final String userId;
  final WorkTargetKind kind;
  final String targetId;
  final String targetName;
  final String projectId;
  /// Se true (só em projetos), inclui também segmentos de temas/desenvolvimentos
  /// do mesmo [projectId].
  final bool includeChildrenUnderProject;

  const WorkTimerSessionsCard({
    super.key,
    required this.service,
    required this.userId,
    required this.kind,
    required this.targetId,
    required this.targetName,
    String? projectId,
    this.includeChildrenUnderProject = false,
  }) : projectId = projectId ?? targetId;

  Stream<List<WorkTimeSegment>> _stream() {
    if (includeChildrenUnderProject && kind == WorkTargetKind.project) {
      return service.watchWorkSegmentsForProject(
        userId: userId,
        projectId: this.projectId,
        limit: 200,
      );
    }
    return service.watchWorkSegments(
      userId: userId,
      kind: kind,
      targetId: targetId,
      limit: 100,
    );
  }

  String _kindBadge(WorkTargetKind k) {
    switch (k) {
      case WorkTargetKind.project:
        return 'Projeto';
      case WorkTargetKind.theme:
        return 'Tema';
      case WorkTargetKind.development:
        return 'Desenvolvimento';
    }
  }

  IconData _kindIcon(WorkTargetKind k) {
    switch (k) {
      case WorkTargetKind.project:
        return Icons.folder_outlined;
      case WorkTargetKind.theme:
        return Icons.topic_outlined;
      case WorkTargetKind.development:
        return Icons.code_outlined;
    }
  }

  Future<void> _insert(BuildContext context) async {
    final ok = await showManualWorkSegmentDialog(
      context,
      service: service,
      userId: userId,
      kind: kind,
      targetId: targetId,
      projectId: projectId,
      targetName: targetName,
    );
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tempo manual gravado.')),
      );
    }
  }

  Future<void> _delete(BuildContext context, WorkTimeSegment s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Apagar tempo manual?'),
        content: const Text(
          'Só segmentos introduzidos manualmente podem ser apagados. '
          'O total deste alvo é actualizado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await service.deleteManualWorkSegment(
        userId: userId,
        segmentId: s.id,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não apaguei: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) return const SizedBox.shrink();

    final dayFmt = DateFormat('dd/MM/yyyy');
    final timeFmt = DateFormat('HH:mm');

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Linha de tempo (relógio)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _insert(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Inserir'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              includeChildrenUnderProject
                  ? 'Segmentos do timer neste projeto (inclui temas e desenvolvimentos), agrupados por dia. Usa «Inserir» para tempos manuais.'
                  : 'Segmentos do timer neste ${kind.label}, agrupados por dia. Usa «Inserir» para tempos manuais com descrição.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.3,
                color: Colors.grey.shade700,
              ),
            ),
            const Divider(height: 18),
            StreamBuilder<List<WorkTimeSegment>>(
              stream: _stream(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text(
                    'Erro ao carregar segmentos: ${snap.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  );
                }
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final segments = snap.data!;
                if (segments.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Ainda sem registos do relógio em «$targetName». '
                      'Usa «Inserir» ou arranca o timer.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  );
                }

                final byDay = groupWorkSegmentsByLocalDay(segments);
                final days = byDay.keys.toList();
                var shown = 0;
                const maxItems = 40;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final day in days) ...[
                      if (shown < maxItems) ...[
                        Text(
                          dayFmt.format(day),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...byDay[day]!.map((s) {
                          if (shown >= maxItems) {
                            return const SizedBox.shrink();
                          }
                          shown++;
                          final title = s.description.isEmpty
                              ? '(sem descrição)'
                              : s.description;
                          final showKind = includeChildrenUnderProject &&
                              s.kind != WorkTargetKind.project;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0x1A1A237E),
                                child: Icon(
                                  s.isManual
                                      ? Icons.edit_calendar_outlined
                                      : _kindIcon(s.kind),
                                  color: Colors.blueGrey[700],
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                '$title · ${formatWorkDurationSeconds(s.durationSeconds)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                '${timeFmt.format(s.startedAt)} → ${timeFmt.format(s.endedAt)}'
                                '${s.isManual ? ' · manual' : ''}'
                                '${showKind ? ' · ${_kindBadge(s.kind)}' : ''}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade700,
                                  height: 1.3,
                                ),
                              ),
                              trailing: s.isManual
                                  ? IconButton(
                                      tooltip: 'Apagar tempo manual',
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: Colors.red.shade400,
                                        size: 20,
                                      ),
                                      onPressed: () => _delete(context, s),
                                    )
                                  : null,
                            ),
                          );
                        }),
                        const SizedBox(height: 4),
                      ],
                    ],
                    if (segments.length > maxItems)
                      Text(
                        '… e mais ${segments.length - maxItems} segmentos',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
