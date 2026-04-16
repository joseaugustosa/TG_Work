import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/project.dart';
import '../../models/theme_item.dart';
import '../../models/development.dart';
import '../../services/firestore_service.dart';
import '../../utils/user_display.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/status_history_sheet.dart';
import 'development_detail_screen.dart';

class DevelopmentsScreen extends StatelessWidget {
  final ThemeItem theme;
  final Project project;

  const DevelopmentsScreen({super.key, required this.theme, required this.project});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final user = FirebaseAuth.instance.currentUser;
    final userName = firebaseUserDisplayLabel(user);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(theme.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Text('Desenvolvimentos',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Development>>(
        stream: firestoreService.getDevelopments(theme.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final devs = snapshot.data ?? [];
          if (devs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.code_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Nenhum desenvolvimento ainda.\nClica no + para criar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: devs.length,
            itemBuilder: (context, index) {
              final dev = devs[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: devStatusColor(dev.status).withValues(alpha: 0.15),
                    child: Icon(Icons.code, color: devStatusColor(dev.status)),
                  ),
                  title: Text(dev.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dev.description.isNotEmpty) Text(dev.description),
                      _AuditLine(dev: dev),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(
                        label: dev.status.label,
                        color: devStatusColor(dev.status),
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            _showDevDialog(
                              context,
                              firestoreService,
                              dev: dev,
                              userId: user?.uid ?? '',
                              userName: userName,
                            );
                          } else if (value == 'history') {
                            StatusHistorySheet.show(
                              context,
                              entityId: dev.id,
                              entityName: dev.name,
                            );
                          } else if (value == 'delete') {
                            await firestoreService.deleteDevelopment(dev.id);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('Editar')),
                          const PopupMenuItem(
                            value: 'history',
                            child: Row(
                              children: [
                                Icon(Icons.history, size: 18, color: Colors.grey),
                                SizedBox(width: 8),
                                Text('Histórico'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DevelopmentDetailScreen(
                        devId: dev.id,
                        devName: dev.name,
                        theme: theme,
                        project: project,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        onPressed: () => _showDevDialog(
          context,
          firestoreService,
          userId: user?.uid ?? '',
          userName: userName,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDevDialog(
    BuildContext context,
    FirestoreService service, {
    Development? dev,
    required String userId,
    required String userName,
  }) {
    final nameController = TextEditingController(text: dev?.name ?? '');
    final descController = TextEditingController(text: dev?.description ?? '');
    DevelopmentStatus status = dev?.status ?? DevelopmentStatus.emAndamento;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(dev == null ? 'Novo Desenvolvimento' : 'Editar Desenvolvimento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Nome', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                      labelText: 'Descrição / introdução', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<DevelopmentStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(
                      labelText: 'Estado', border: OutlineInputBorder()),
                  items: DevelopmentStatus.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                      .toList(),
                  onChanged: (v) => setState(() => status = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final d = Development(
                  id: dev?.id ?? '',
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  status: status,
                  themeId: theme.id,
                  projectId: project.id,
                  createdBy: dev?.createdBy ?? userId,
                  createdByName: dev?.createdByName ?? userName,
                  createdAt: dev?.createdAt ?? DateTime.now(),
                );
                if (dev == null) {
                  await service.addDevelopment(
                    d,
                    userId: userId,
                    userName: userName,
                  );
                } else {
                  await service.updateDevelopment(
                    d,
                    oldDev: dev,
                    userId: userId,
                    userName: userName,
                  );
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(dev == null ? 'Criar' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditLine extends StatelessWidget {
  final Development dev;

  const _AuditLine({required this.dev});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yy HH:mm');
    if (dev.updatedBy != null && dev.updatedAt != null) {
      final name = auditActorLabel(
        storedDisplayName: dev.updatedByName,
        uidOrEmpty: dev.updatedBy ?? '',
      );
      return Text(
        'Atualizado por $name · ${fmt.format(dev.updatedAt!)}',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      );
    }
    if (dev.createdBy.isNotEmpty || dev.createdByName.isNotEmpty) {
      final name = auditActorLabel(
        storedDisplayName:
            dev.createdByName.isNotEmpty ? dev.createdByName : null,
        uidOrEmpty: dev.createdBy,
      );
      return Text(
        'Criado por $name · ${fmt.format(dev.createdAt)}',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      );
    }
    return const SizedBox.shrink();
  }
}
