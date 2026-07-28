import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ide_session_log.dart';
import '../models/ide_session_kind.dart';
import '../services/firestore_service.dart';
import '../utils/work_timer_format.dart';
import 'manual_ide_session_dialog.dart';

/// Lista sessões do projeto + botão para inserir sessão manual.
class ProjectIdeSessionsCard extends StatelessWidget {
  final FirestoreService service;
  final String projectId;
  final String projectName;
  final String userId;

  const ProjectIdeSessionsCard({
    super.key,
    required this.service,
    required this.projectId,
    required this.projectName,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) return const SizedBox.shrink();

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
                    'Sessões (Agenda IDE)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final ok = await showManualIdeSessionDialog(
                      context,
                      service: service,
                      userId: userId,
                      projectId: projectId,
                      projectName: projectName,
                    );
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Sessão gravada — entra no Kanban da Agenda IDE.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Inserir'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Contabilização só por sessões (IDE automática ou manual: '
              'VS Code, Cursor, montagem hardware/física).',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.3,
                color: Colors.grey.shade700,
              ),
            ),
            const Divider(height: 18),
            StreamBuilder<IdeSessionLogsQuerySnapshot>(
              stream: service.watchIdeSessionLogs(userId, limit: 800),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text(
                    'Erro ao carregar sessões: ${snap.error}',
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
                final logs = snap.data!.completedSessions
                    .where((l) => l.tgProjectId.trim() == projectId)
                    .toList();
                if (logs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Ainda sem sessões neste projeto. Usa «Inserir» ou abre o workspace na IDE.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                    ),
                  );
                }

                final fmt = DateFormat('dd/MM/yyyy');
                return Column(
                  children: [
                    for (final log in logs.take(25))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(
                          log.isManual
                              ? Icons.edit_calendar_outlined
                              : Icons.terminal,
                          color: const Color(0xFF1A237E),
                          size: 22,
                        ),
                        title: Text(
                          '${ideSessionEditorLabelPt(log.editor)} · '
                          '${formatWorkDurationSeconds(log.durationSeconds)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          '${fmt.format(log.closedAt)}'
                          '${log.isManual ? ' · manual' : ''}'
                          '${log.workspaceName.trim().isNotEmpty ? '\n${log.workspaceName}' : ''}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                        ),
                        trailing: log.isManual
                            ? IconButton(
                                tooltip: 'Apagar sessão manual',
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red.shade400,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Apagar sessão?'),
                                      content: const Text(
                                        'Só sessões manuais podem ser apagadas.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(c, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(c, true),
                                          child: const Text('Apagar'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm != true) return;
                                  try {
                                    await service.deleteManualIdeSession(
                                      userId: userId,
                                      sessionId: log.id,
                                    );
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text('Não apaguei: $e'),
                                        ),
                                      );
                                    }
                                  }
                                },
                              )
                            : null,
                      ),
                    if (logs.length > 25)
                      Text(
                        '… e mais ${logs.length - 25} sessões',
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

/// Atalho estático quando o [userId] vem do FirebaseAuth no ecrã.
class ProjectIdeSessionsCardAuth extends StatelessWidget {
  final FirestoreService service;
  final String projectId;
  final String projectName;

  const ProjectIdeSessionsCardAuth({
    super.key,
    required this.service,
    required this.projectId,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return ProjectIdeSessionsCard(
      service: service,
      projectId: projectId,
      projectName: projectName,
      userId: uid,
    );
  }
}
