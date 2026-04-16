import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/project.dart';
import '../../models/theme_item.dart';
import '../../services/firestore_service.dart';
import '../../utils/user_display.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/status_history_sheet.dart';
import 'theme_detail_screen.dart';

class ThemesScreen extends StatelessWidget {
  final Project project;

  const ThemesScreen({super.key, required this.project});

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
            Text(project.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Text('Temas',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<ThemeItem>>(
        stream: firestoreService.getThemes(project.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final themes = snapshot.data ?? [];
          if (themes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.topic_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Nenhum tema ainda.\nClica no + para criar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: themes.length,
            itemBuilder: (context, index) {
              final theme = themes[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor:
                        themeStatusColor(theme.status).withValues(alpha: 0.15),
                    child: Icon(Icons.topic, color: themeStatusColor(theme.status)),
                  ),
                  title: Text(theme.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (theme.description.isNotEmpty) Text(theme.description),
                      _AuditLine(theme: theme),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(
                        label: theme.status.label,
                        color: themeStatusColor(theme.status),
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            _showThemeDialog(
                              context,
                              firestoreService,
                              theme: theme,
                              userId: user?.uid ?? '',
                              userName: userName,
                            );
                          } else if (value == 'history') {
                            StatusHistorySheet.show(
                              context,
                              entityId: theme.id,
                              entityName: theme.name,
                            );
                          } else if (value == 'delete') {
                            await firestoreService.deleteTheme(theme.id);
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
                      builder: (_) => ThemeDetailScreen(
                        themeId: theme.id,
                        themeName: theme.name,
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
        onPressed: () => _showThemeDialog(
          context,
          firestoreService,
          userId: user?.uid ?? '',
          userName: userName,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showThemeDialog(
    BuildContext context,
    FirestoreService service, {
    ThemeItem? theme,
    required String userId,
    required String userName,
  }) {
    final nameController = TextEditingController(text: theme?.name ?? '');
    final descController = TextEditingController(text: theme?.description ?? '');
    ThemeStatus status = theme?.status ?? ThemeStatus.emEstudo;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(theme == null ? 'Novo Tema' : 'Editar Tema'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Nome do tema', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                      labelText: 'Descrição / introdução', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ThemeStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(
                      labelText: 'Estado', border: OutlineInputBorder()),
                  items: ThemeStatus.values
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
                final t = ThemeItem(
                  id: theme?.id ?? '',
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  status: status,
                  projectId: project.id,
                  createdBy: theme?.createdBy ?? userId,
                  createdByName: theme?.createdByName ?? userName,
                  createdAt: theme?.createdAt ?? DateTime.now(),
                );
                if (theme == null) {
                  await service.addTheme(
                    t,
                    userId: userId,
                    userName: userName,
                  );
                } else {
                  await service.updateTheme(
                    t,
                    oldTheme: theme,
                    userId: userId,
                    userName: userName,
                  );
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(theme == null ? 'Criar' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditLine extends StatelessWidget {
  final ThemeItem theme;

  const _AuditLine({required this.theme});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yy HH:mm');
    if (theme.updatedBy != null && theme.updatedAt != null) {
      final name = auditActorLabel(
        storedDisplayName: theme.updatedByName,
        uidOrEmpty: theme.updatedBy ?? '',
      );
      return Text(
        'Atualizado por $name · ${fmt.format(theme.updatedAt!)}',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      );
    }
    if (theme.createdBy.isNotEmpty || theme.createdByName.isNotEmpty) {
      final name = auditActorLabel(
        storedDisplayName:
            theme.createdByName.isNotEmpty ? theme.createdByName : null,
        uidOrEmpty: theme.createdBy,
      );
      return Text(
        'Criado por $name · ${fmt.format(theme.createdAt)}',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      );
    }
    return const SizedBox.shrink();
  }
}
