import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/status_change.dart';
import '../services/firestore_service.dart';

class StatusHistorySheet extends StatelessWidget {
  final String entityId;
  final String entityName;

  const StatusHistorySheet({
    super.key,
    required this.entityId,
    required this.entityName,
  });

  static void show(BuildContext context, {required String entityId, required String entityName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatusHistorySheet(entityId: entityId, entityName: entityName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Color(0xFF1A237E)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Histórico de Estado',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                        Text(
                          entityName,
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<StatusChange>>(
                stream: service.getStatusHistory(entityId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final changes = snapshot.data ?? [];
                  if (changes.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off, size: 56, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'Sem alterações de estado registadas.',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: changes.length,
                    separatorBuilder: (context, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final change = changes[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A237E).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.swap_horiz,
                                size: 18,
                                color: Color(0xFF1A237E),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _StatusChip(label: change.oldStatusLabel, old: true),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 6),
                                        child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                                      ),
                                      _StatusChip(label: change.newStatusLabel, old: false),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    change.changedByName.isNotEmpty
                                        ? change.changedByName
                                        : change.changedBy,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    fmt.format(change.changedAt),
                                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool old;

  const _StatusChip({required this.label, required this.old});

  @override
  Widget build(BuildContext context) {
    final color = old ? Colors.grey[600]! : const Color(0xFF1A237E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
