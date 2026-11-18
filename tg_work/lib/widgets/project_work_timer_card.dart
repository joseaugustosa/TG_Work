import 'dart:async';

import 'package:flutter/material.dart';

import '../models/active_work_clock.dart';
import '../models/work_target_kind.dart';
import '../services/firestore_service.dart';
import '../utils/work_timer_format.dart';

/// Tempo neste alvo (projeto / tema / desenvolvimento):
/// Arrancar, Pausar, Retomar, Gravar e Terminar, com descrição da tarefa.
class ProjectWorkTimerCard extends StatefulWidget {
  final WorkTargetKind kind;
  final String targetId;
  final String targetName;
  final String projectId;
  final String userId;
  final FirestoreService service;
  /// Se false, não permite iniciar (ex.: projeto não «Em Execução»).
  final bool canStartByStatus;
  final String lockedStatusMessage;

  const ProjectWorkTimerCard({
    super.key,
    this.kind = WorkTargetKind.project,
    required this.targetId,
    required this.targetName,
    String? projectId,
    required this.userId,
    required this.service,
    this.canStartByStatus = true,
    this.lockedStatusMessage =
        'O relógio só conta neste estado de trabalho.',
  }) : projectId = projectId ?? targetId;

  /// Compat com ecrã de projeto.
  factory ProjectWorkTimerCard.forProject({
    Key? key,
    required String projectId,
    required String projectName,
    required String userId,
    required FirestoreService service,
    required bool canStartByStatus,
  }) {
    return ProjectWorkTimerCard(
      key: key,
      kind: WorkTargetKind.project,
      targetId: projectId,
      targetName: projectName,
      projectId: projectId,
      userId: userId,
      service: service,
      canStartByStatus: canStartByStatus,
      lockedStatusMessage:
          'O relógio só conta quando o projeto está em «Em Execução».',
    );
  }

  @override
  State<ProjectWorkTimerCard> createState() => _ProjectWorkTimerCardState();
}

class _ProjectWorkTimerCardState extends State<ProjectWorkTimerCard> {
  bool _busy = false;
  late final TextEditingController _descCtrl;
  Timer? _descDebounce;
  String _lastSyncedDesc = '';

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _descDebounce?.cancel();
    _descCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  Future<void> _run(Future<void> Function() action, String okMsg) async {
    if (widget.userId.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && okMsg.isNotEmpty) _snack(okMsg);
    } catch (e) {
      _snack('Erro: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() => _run(
        () => widget.service.startWorkTimer(
          userId: widget.userId,
          kind: widget.kind,
          targetId: widget.targetId,
          projectId: widget.projectId,
          taskDescription: _descCtrl.text,
        ),
        'Tempo a contar.',
      );

  Future<void> _pause() => _run(
        () => widget.service.pauseWorkTimer(widget.userId),
        'Em pausa — tempo gravado.',
      );

  Future<void> _resume() => _run(
        () => widget.service.resumeWorkTimer(widget.userId),
        'Retomado.',
      );

  Future<void> _stop() => _run(
        () => widget.service.stopProjectWorkTimer(widget.userId),
        'Terminado — tempo gravado.',
      );

  Future<void> _saveCheckpoint() => _run(
        () => widget.service.checkpointProjectWorkTimer(widget.userId),
        'Segmento gravado — contagem continua.',
      );

  void _onDescChanged(ActiveWorkClock? clock) {
    final activeHere = clock?.isActiveOn(widget.kind, widget.targetId) == true;
    if (!activeHere) return;
    final text = _descCtrl.text.trim();
    if (text == _lastSyncedDesc) return;
    _descDebounce?.cancel();
    _descDebounce = Timer(const Duration(milliseconds: 600), () async {
      _lastSyncedDesc = text;
      try {
        await widget.service
            .updateWorkTimerTaskDescription(widget.userId, text);
      } catch (_) {}
    });
  }

  void _syncDescFromClock(ActiveWorkClock? clock) {
    final activeHere = clock?.isActiveOn(widget.kind, widget.targetId) == true;
    if (!activeHere) return;
    final remote = clock?.taskDescription ?? '';
    if (remote == _descCtrl.text) {
      _lastSyncedDesc = remote;
      return;
    }
    // Só sincroniza se o campo local ainda está vazio ou igual ao último sync.
    if (_descCtrl.text.isEmpty || _descCtrl.text == _lastSyncedDesc) {
      _descCtrl.text = remote;
      _lastSyncedDesc = remote;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty) return const SizedBox.shrink();

    final kindLabel = widget.kind.label;

    return StreamBuilder<ActiveWorkClock?>(
      stream: widget.service.watchActiveWorkClock(widget.userId),
      builder: (context, clockSnap) {
        final clock = clockSnap.data;
        final activeHere =
            clock?.isActiveOn(widget.kind, widget.targetId) == true;
        final runningHere =
            clock?.isRunningOn(widget.kind, widget.targetId) == true;
        final pausedHere = activeHere && (clock?.paused == true);

        if (activeHere) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncDescFromClock(clock);
          });
        }

        return StreamBuilder<int>(
          stream: widget.service.watchEntityWorkedSeconds(
            widget.userId,
            widget.kind,
            widget.targetId,
          ),
          builder: (context, totalSnap) {
            final logged = totalSnap.data ?? 0;

            Widget body(int tick) {
              final segmentSec = runningHere && clock != null
                  ? clock.liveSegmentSeconds(DateTime.now())
                  : 0;
              final displayTotal = logged + segmentSec;
              final canStart =
                  widget.canStartByStatus && !_busy && !activeHere;
              final canControl = !_busy && activeHere;

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            color: activeHere
                                ? (pausedHere
                                    ? Colors.blueGrey[700]
                                    : Colors.orange[800])
                                : Colors.grey[800],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              activeHere
                                  ? (pausedHere
                                      ? 'Em pausa neste $kindLabel'
                                      : 'A registar tempo neste $kindLabel')
                                  : 'Tempo de trabalho',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF1A237E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (!widget.canStartByStatus)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock_outline,
                                  size: 18, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.lockedStatusMessage,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[700]),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          'Descreve a tarefa, arranca, pausa/retoma e termina '
                          'para gravar no $kindLabel. Só podes contar num sítio de cada vez.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            height: 1.35,
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descCtrl,
                        enabled: !_busy &&
                            (widget.canStartByStatus || activeHere),
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Descrição da tarefa',
                          hintText: 'Ex.: implementar autenticação',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => _onDescChanged(clock),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Tempo gravado (${widget.targetName})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatWorkDurationSeconds(displayTotal),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (runningHere) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Sessão actual: ${formatWorkDurationSeconds(segmentSec)}',
                          style:
                              TextStyle(fontSize: 13, color: Colors.orange[900]),
                        ),
                      ],
                      if (pausedHere) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Em pausa — retoma para continuar.',
                          style:
                              TextStyle(fontSize: 13, color: Colors.blueGrey[800]),
                        ),
                      ],
                      if (clock != null && !activeHere) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 20, color: Colors.amber[900]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Estás a registar tempo noutro sítio'
                                  '${clock.taskDescription.isNotEmpty ? ' (${clock.taskDescription})' : ''}. '
                                  'Podes passar a contagem para este $kindLabel.',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[900]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1A237E),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: pausedHere
                                  ? (_busy ? null : _resume)
                                  : (canStart ? _start : null),
                              icon: Icon(
                                pausedHere
                                    ? Icons.play_arrow
                                    : Icons.play_arrow,
                              ),
                              label: Text(pausedHere ? 'Retomar' : 'Arrancar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: canControl && runningHere
                                    ? Colors.orange.shade900
                                    : null,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed:
                                  canControl && runningHere ? _pause : null,
                              icon: const Icon(Icons.pause),
                              label: const Text('Pausar'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: canControl && runningHere
                                    ? const Color(0xFF1A237E)
                                    : null,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: canControl && runningHere
                                  ? _saveCheckpoint
                                  : null,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Gravar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    canControl ? Colors.red.shade800 : null,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: canControl ? _stop : null,
                              icon: const Icon(Icons.stop),
                              label: const Text('Terminar'),
                            ),
                          ),
                        ],
                      ),
                      if (widget.canStartByStatus &&
                          clock != null &&
                          !activeHere) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: _busy ? null : _start,
                            icon: const Icon(Icons.swap_horiz),
                            label: Text(
                                'Passar contagem para este $kindLabel'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _SegmentsList(
                        service: widget.service,
                        userId: widget.userId,
                        kind: widget.kind,
                        targetId: widget.targetId,
                      ),
                    ],
                  ),
                ),
              );
            }

            if (runningHere) {
              return StreamBuilder<int>(
                stream: Stream.periodic(
                  const Duration(seconds: 1),
                  (i) => i,
                ),
                initialData: 0,
                builder: (context, tickSnap) => body(tickSnap.data ?? 0),
              );
            }
            return body(0);
          },
        );
      },
    );
  }
}

class _SegmentsList extends StatelessWidget {
  final FirestoreService service;
  final String userId;
  final WorkTargetKind kind;
  final String targetId;

  const _SegmentsList({
    required this.service,
    required this.userId,
    required this.kind,
    required this.targetId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WorkTimeSegment>>(
      stream: service.watchWorkSegments(
        userId: userId,
        kind: kind,
        targetId: targetId,
        limit: 8,
      ),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            'Histórico de tarefas indisponível por agora.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          );
        }
        final items = snap.data ?? const <WorkTimeSegment>[];
        if (items.isEmpty) {
          return Text(
            'Ainda sem segmentos gravados.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Últimas tarefas',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 6),
            ...items.map((s) {
              final title = s.description.isEmpty
                  ? '(sem descrição)'
                  : s.description;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatWorkDurationSeconds(s.durationSeconds),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
