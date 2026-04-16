import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/project.dart';
import '../../models/status_change.dart';
import '../../services/firestore_service.dart';
import '../../utils/user_display.dart';
import '../../widgets/status_badge.dart';
import '../themes/themes_screen.dart';

class ProjectDetailScreen extends StatelessWidget {
  final String projectId;
  final String projectName;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final user = FirebaseAuth.instance.currentUser;
    final userName = firebaseUserDisplayLabel(user);

    return StreamBuilder<Project?>(
      stream: service.watchProject(projectId),
      builder: (context, snapshot) {
        final project = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              project?.name ?? projectName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            actions: [
              if (project != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar',
                  onPressed: () => _showEditDialog(
                    context,
                    service,
                    project,
                    userId: user?.uid ?? '',
                    userName: userName,
                  ),
                ),
            ],
          ),
          body: project == null
              ? const Center(child: CircularProgressIndicator())
              : _ProjectDetailBody(
                  project: project,
                  service: service,
                  userId: user?.uid ?? '',
                  userName: userName,
                ),
        );
      },
    );
  }

  void _showEditDialog(
    BuildContext context,
    FirestoreService service,
    Project project, {
    required String userId,
    required String userName,
  }) {
    final nameController = TextEditingController(text: project.name);
    final descController = TextEditingController(text: project.description);
    ProjectStatus status = project.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Editar Projeto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do projeto',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição / introdução',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ProjectStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    border: OutlineInputBorder(),
                  ),
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final updated = Project(
                  id: project.id,
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  status: status,
                  createdBy: project.createdBy,
                  createdByName: project.createdByName,
                  createdAt: project.createdAt,
                );
                await service.updateProject(
                  updated,
                  oldProject: project,
                  userId: userId,
                  userName: userName,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectDetailBody extends StatelessWidget {
  final Project project;
  final FirestoreService service;
  final String userId;
  final String userName;

  const _ProjectDetailBody({
    required this.project,
    required this.service,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(project: project, fmt: fmt),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF1A237E)),
            foregroundColor: const Color(0xFF1A237E),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.topic_outlined),
          label: const Text('Ver Temas'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ThemesScreen(project: project)),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Histórico de Alterações',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<StatusChange>>(
          stream: service.getStatusHistory(project.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final changes = snapshot.data ?? [];
            if (changes.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history_toggle_off, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'Sem alterações de estado registadas.',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: changes
                  .map((c) => _HistoryTile(change: c, fmt: fmt))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Project project;
  final DateFormat fmt;

  const _InfoCard({required this.project, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0x1A1A237E),
                  child: Icon(Icons.folder, color: Color(0xFF1A237E)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    project.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                StatusBadge(
                  label: project.status.label,
                  color: projectStatusColor(project.status),
                ),
              ],
            ),
            if (project.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(project.description, style: TextStyle(color: Colors.grey[700])),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _auditText(project, fmt),
          ],
        ),
      ),
    );
  }

  Widget _auditText(Project p, DateFormat f) {
    if (p.updatedBy != null && p.updatedAt != null) {
      final name = auditActorLabel(
        storedDisplayName: p.updatedByName,
        uidOrEmpty: p.updatedBy ?? '',
      );
      return _AuditRow(icon: Icons.edit, text: 'Editado por $name · ${f.format(p.updatedAt!)}');
    }
    final name = auditActorLabel(
      storedDisplayName: p.createdByName.isNotEmpty ? p.createdByName : null,
      uidOrEmpty: p.createdBy,
    );
    return _AuditRow(icon: Icons.person_add_alt, text: 'Criado por $name · ${f.format(p.createdAt)}');
  }
}

class _AuditRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _AuditRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final StatusChange change;
  final DateFormat fmt;

  const _HistoryTile({required this.change, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
            child: const Icon(Icons.swap_horiz, size: 18, color: Color(0xFF1A237E)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusChip(label: change.oldStatusLabel, isOld: true),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                    ),
                    _StatusChip(label: change.newStatusLabel, isOld: false),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  auditActorLabel(
                    storedDisplayName: change.changedByName,
                    uidOrEmpty: change.changedBy,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isOld;

  const _StatusChip({required this.label, required this.isOld});

  @override
  Widget build(BuildContext context) {
    final color = isOld ? Colors.grey[600]! : const Color(0xFF1A237E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
