import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/note_recording_holder.dart';
import '../../models/project.dart';
import '../../models/status_change.dart';
import '../../services/firestore_service.dart';
import '../../services/note_recording_storage.dart';
import '../../utils/firestore_messages.dart';
import '../../utils/ide_workspace_path_pick.dart';
import '../../utils/windows_firestore_compat.dart';
import '../../utils/user_display.dart';
import '../../widgets/status_badge.dart';
import '../../models/journal_note.dart';
import '../../widgets/entity_notes_section.dart';
import '../../widgets/note_recording_editor.dart';
import '../../widgets/note_recording_playback.dart';
import '../../widgets/voice_dictation_text_field.dart';
import '../../widgets/history_entry_tile.dart';
import '../../widgets/project_work_timer_card.dart';
import '../../widgets/project_workspace_timer_host.dart';
import '../../widgets/project_ide_sessions_card.dart';
import '../themes/themes_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late final FirestoreService _service;
  late final Stream<Project?> _projectStream;
  late final Stream<List<StatusChange>> _projectHistoryStream;

  @override
  void initState() {
    super.initState();
    // Stream estável por ecrã: evita unsubscribe/resubscribe a cada rebuild (que dizimava o relógio e o body).
    _service = FirestoreService();
    _projectStream = _service.watchProject(widget.projectId);
    _projectHistoryStream = _service.getStatusHistory(widget.projectId);
  }

  Future<void> _showEditDialog(
    BuildContext context,
    Project project, {
    required String userId,
    required String userName,
  }) async {
    final nameController = TextEditingController(text: project.name);
    final descController = TextEditingController(text: project.description);
    final idePathController =
        TextEditingController(text: project.ideCountingFolderFsPath);
    final recordingHolder = NoteRecordingHolder(originalUrl: project.descriptionRecordingUrl);
    ProjectStatus status = project.status;

    try {
      await showDialog(
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
                  VoiceDictationTextField(
                    controller: descController,
                    labelText: 'Descrição / introdução',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  NoteRecordingEditor(
                    holder: recordingHolder,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: idePathController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Pasta / atalho workspace no PC (contagem IDE)',
                            hintText:
                                r'Ex.: C:\dev\meu-repo  ou  C:\atalhos\Projeto.code-workspace',
                            helperText:
                                'Opcional. Com login Firebase na extensão TG Work IDE, o projeto costuma ligar‑se só '
                                'pela pasta aberta (coincidência com campo/Firestore) ou pelo nome da pasta '
                                '(único). Ou escolhes o caminho ao lado.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Escolher pasta ou ficheiro…',
                        onPressed: () async {
                          if (kIsWeb) {
                            ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Na Web não há acesso aos ficheiros do teu PC. '
                                  'Escreve o caminho ou usa a app no Windows/Android.',
                                ),
                              ),
                            );
                            return;
                          }
                          final p = await pickIdeWorkspaceFilesystemPath(ctx);
                          if (p != null && ctx.mounted) {
                            idePathController.text = p;
                            setState(() {});
                          }
                        },
                        icon: const Icon(Icons.folder_open_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Estado',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ProjectStatus>(
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(4),
                        value: status,
                        items: ProjectStatus.values
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s.label)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => status = v);
                        },
                      ),
                    ),
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
                  final audioUrl = await NoteRecordingStorage.resolveOnSave(
                    holder: recordingHolder,
                    uploadPending: (f) =>
                        NoteRecordingStorage.uploadProjectNote(project.id, f),
                  );
                  final updated = Project(
                    id: project.id,
                    name: nameController.text.trim(),
                    description: descController.text.trim(),
                    descriptionRecordingUrl: audioUrl,
                    status: status,
                    ideCountingFolderFsPath: idePathController.text.trim(),
                    createdBy: project.createdBy,
                    createdByName: project.createdByName,
                    createdAt: project.createdAt,
                  );
                  await _service.updateProject(
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
    } finally {
      nameController.dispose();
      descController.dispose();
      idePathController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = firebaseUserDisplayLabel(user);

    return StreamBuilder<Project?>(
      stream: _projectStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                widget.projectName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      firestoreHistoryErrorHint(snapshot.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final project = snapshot.data;
        final stillLoadingProject =
            !snapshot.hasData && snapshot.connectionState == ConnectionState.waiting;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              project?.name ?? widget.projectName,
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
                    project,
                    userId: user?.uid ?? '',
                    userName: userName,
                  ),
                ),
            ],
          ),
          body: stillLoadingProject || project == null
              ? const Center(child: CircularProgressIndicator())
              : ProjectWorkspaceTimerHost(
                  userId: user?.uid ?? '',
                  projectId: project.id,
                  projectStatus: project.status,
                  child: _ProjectDetailBody(
                    project: project,
                    service: _service,
                    historyStream: _projectHistoryStream,
                    userId: user?.uid ?? '',
                    userName: userName,
                  ),
                ),
        );
      },
    );
  }
}

class _ProjectDetailBody extends StatelessWidget {
  final Project project;
  final FirestoreService service;
  final Stream<List<StatusChange>> historyStream;
  final String userId;
  final String userName;

  const _ProjectDetailBody({
    required this.project,
    required this.service,
    required this.historyStream,
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
        const SizedBox(height: 16),
        if (!disableManualWorkTimerOnDesktop)
          ProjectWorkTimerCard(
            projectId: project.id,
            projectName: project.name,
            userId: userId,
            service: service,
            projectStatus: project.status,
          ),
        const SizedBox(height: 16),
        ProjectIdeSessionsCard(
          service: service,
          projectId: project.id,
          projectName: project.name,
          userId: userId,
        ),
        const SizedBox(height: 20),
        EntityNotesSection(
          parent: JournalNoteParent.project,
          parentId: project.id,
          service: service,
          userId: userId,
          userName: userName,
        ),
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
          'Histórico de alterações',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<StatusChange>>(
          stream: historyStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Erro ao carregar histórico: ${firestoreHistoryErrorHint(snapshot.error)}',
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
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
                        'Sem alterações registadas.',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: changes
                  .map((c) => HistoryEntryTile(change: c, fmt: fmt))
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
            NoteRecordingPlayback(downloadUrl: project.descriptionRecordingUrl),
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
