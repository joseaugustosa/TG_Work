import 'package:flutter/material.dart';

import '../models/active_work_clock.dart';
import '../models/project.dart';
import '../services/firestore_service.dart';
import '../utils/work_timer_format.dart';

/// Tempo neste projeto: Arrancar, Pausar, Parar e Gravar (checkpoint).
/// Só permite iniciar se [projectStatus] == [ProjectStatus.emExecucao].
class ProjectWorkTimerCard extends StatefulWidget {
  final String projectId;
  final String projectName;
  final String userId;
  final FirestoreService service;
  final ProjectStatus projectStatus;

  const ProjectWorkTimerCard({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.userId,
    required this.service,
    required this.projectStatus,
  });

  @override
  State<ProjectWorkTimerCard> createState() => _ProjectWorkTimerCardState();
}

class _ProjectWorkTimerCardState extends State<ProjectWorkTimerCard> {
  bool _busy = false;

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
        () => widget.service.startProjectWorkTimer(widget.userId, widget.projectId),
        'Tempo a contar.',
      );

  Future<void> _pause() => _run(
        () => widget.service.stopProjectWorkTimer(widget.userId),
        'Pausado — tempo gravado.',
      );

  Future<void> _stop() => _run(
        () => widget.service.stopProjectWorkTimer(widget.userId),
        'Parado — tempo gravado.',
      );

  Future<void> _saveCheckpoint() => _run(
        () => widget.service.checkpointProjectWorkTimer(widget.userId),
        'Segmento gravado — contagem continua.',
      );

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<ActiveWorkClock?>(
      stream: widget.service.watchActiveWorkClock(widget.userId),
      builder: (context, clockSnap) {
        final clock = clockSnap.data;
        final activeHere = clock?.projectId == widget.projectId;

        return StreamBuilder<int>(
          stream: widget.service
              .watchProjectWorkedSeconds(widget.userId, widget.projectId),
          builder: (context, totalSnap) {
            final logged = totalSnap.data ?? 0;

            Widget body(int tick) {
              final segmentSec = activeHere && clock != null
                  ? DateTime.now()
                      .difference(clock.segmentStartedAt)
                      .inSeconds
                      .clamp(0, 8640000)
                  : 0;
              final displayTotal = logged + segmentSec;
              final isEmExecucao =
                  widget.projectStatus == ProjectStatus.emExecucao;
              final canStart = isEmExecucao && !_busy && !activeHere;
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
                                ? Colors.orange[800]
                                : Colors.grey[800],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              activeHere
                                  ? 'A registar tempo neste projeto'
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
                      if (!isEmExecucao)
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
                                  'O relógio só conta quando o projeto está em «Em Execução».',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[700]),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          'Arrancar inicia a contagem. Pausar ou Parar grava o segmento e pára. '
                          'Gravar guarda o tempo até agora e continua a contar. '
                          'Só podes estar a contar num projeto de cada vez.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            height: 1.35,
                          ),
                        ),
                      const SizedBox(height: 14),
                      Text(
                        'Tempo gravado (${widget.projectName})',
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
                      if (activeHere) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Sessão actual: ${formatWorkDurationSeconds(segmentSec)}',
                          style:
                              TextStyle(fontSize: 13, color: Colors.orange[900]),
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
                                  'Estás a registar tempo noutro projeto. '
                                  'Podes passar a contagem para este.',
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
                              onPressed: canStart ? _start : null,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Arrancar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    canControl ? Colors.orange.shade900 : null,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: canControl ? _pause : null,
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
                                foregroundColor:
                                    canControl ? const Color(0xFF1A237E) : null,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: canControl ? _saveCheckpoint : null,
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
                              label: const Text('Parar'),
                            ),
                          ),
                        ],
                      ),
                      if (isEmExecucao && clock != null && !activeHere) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: _busy ? null : _start,
                            icon: const Icon(Icons.swap_horiz),
                            label: const Text(
                                'Passar contagem para este projeto'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            if (activeHere && clock != null) {
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
