import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/active_work_clock.dart';
import '../models/work_target_kind.dart';
import '../services/firestore_service.dart';
import '../utils/work_segment_timeline.dart';
import '../utils/work_timer_format.dart';

/// Linha de tempo dos segmentos do relógio manual (como as sessões IDE).
class WorkTimerSessionsCard extends StatelessWidget {
  final FirestoreService service;
  final String userId;
  final WorkTargetKind kind;
  final String targetId;
  final String targetName;
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
    this.includeChildrenUnderProject = false,
  });

  Stream<List<WorkTimeSegment>> _stream() {
    if (includeChildrenUnderProject && kind == WorkTargetKind.project) {
      return service.watchWorkSegmentsForProject(
        userId: userId,
        projectId: targetId,
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
            const Text(
              'Linha de tempo (relógio)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              includeChildrenUnderProject
                  ? 'Segmentos do timer neste projeto (inclui temas e desenvolvimentos), agrupados por dia.'
                  : 'Segmentos do timer neste ${kind.label}, agrupados por dia — com a descrição da tarefa.',
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
                      'Arranca o timer e termina (ou pausa) para gravar.',
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
                                  _kindIcon(s.kind),
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
                                '${showKind ? ' · ${_kindBadge(s.kind)}' : ''}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade700,
                                  height: 1.3,
                                ),
                              ),
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
