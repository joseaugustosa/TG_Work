import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/project.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/status_history_sheet.dart';
import '../themes/themes_screen.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final authService = AuthService();
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('TG Work', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sair',
              onPressed: () async => await authService.signOut(),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Project>>(
        stream: firestoreService.getProjects(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          final projects = snapshot.data ?? [];
          if (projects.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Nenhum projeto ainda.\nClica no + para criar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF1A237E).withValues(alpha: 0.1),
                    child: const Icon(Icons.folder, color: Color(0xFF1A237E)),
                  ),
                  title: Text(project.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (project.description.isNotEmpty)
                        Text(project.description),
                      _AuditLine(project: project),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(
                        label: project.status.label,
                        color: projectStatusColor(project.status),
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            _showProjectDialog(
                              context,
                              firestoreService,
                              project: project,
                              userId: user?.uid ?? '',
                              userName: userName,
                            );
                          } else if (value == 'history') {
                            StatusHistorySheet.show(
                              context,
                              entityId: project.id,
                              entityName: project.name,
                            );
                          } else if (value == 'delete') {
                            await firestoreService.deleteProject(project.id);
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
                    MaterialPageRoute(builder: (_) => ThemesScreen(project: project)),
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
        onPressed: () => _showProjectDialog(
          context,
          firestoreService,
          userId: user?.uid ?? '',
          userName: userName,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showProjectDialog(
    BuildContext context,
    FirestoreService service, {
    Project? project,
    required String userId,
    required String userName,
  }) {
    final nameController = TextEditingController(text: project?.name ?? '');
    final descController = TextEditingController(text: project?.description ?? '');
    ProjectStatus status = project?.status ?? ProjectStatus.exequivel;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(project == null ? 'Novo Projeto' : 'Editar Projeto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Nome do projeto', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                      labelText: 'Descrição', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ProjectStatus>(
                  initialValue: status,
                  decoration:
                      const InputDecoration(labelText: 'Estado', border: OutlineInputBorder()),
                  items: ProjectStatus.values
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
                final p = Project(
                  id: project?.id ?? '',
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  status: status,
                  createdBy: project?.createdBy ?? userId,
                  createdByName: project?.createdByName ?? userName,
                  createdAt: project?.createdAt ?? DateTime.now(),
                );
                if (project == null) {
                  await service.addProject(p);
                } else {
                  await service.updateProject(
                    p,
                    oldProject: project,
                    userId: userId,
                    userName: userName,
                  );
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(project == null ? 'Criar' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditLine extends StatelessWidget {
  final Project project;

  const _AuditLine({required this.project});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yy HH:mm');
    if (project.updatedBy != null && project.updatedAt != null) {
      final name = (project.updatedByName?.isNotEmpty == true)
          ? project.updatedByName!
          : project.updatedBy!;
      return Text(
        'Atualizado por $name · ${fmt.format(project.updatedAt!)}',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      );
    }
    if (project.createdByName.isNotEmpty) {
      return Text(
        'Criado por ${project.createdByName} · ${fmt.format(project.createdAt)}',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      );
    }
    return const SizedBox.shrink();
  }
}
