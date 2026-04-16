import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../utils/firestore_messages.dart';
import 'history_entry_tile.dart';

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
                          'Histórico de alterações',
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
              child: StreamBuilder(
                stream: service.getStatusHistory(entityId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            'Não foi possível carregar o histórico.\n${firestoreHistoryErrorHint(snapshot.error)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
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
                            'Sem alterações registadas.',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Se acabaste de guardar e continua vazio, confirma nas regras '
                              'do Firestore permissões para a coleção status_changes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
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
                      return HistoryEntryTile(
                        change: changes[index],
                        fmt: fmt,
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
