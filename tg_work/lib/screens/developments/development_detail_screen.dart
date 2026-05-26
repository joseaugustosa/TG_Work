import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/journal_note.dart';
import '../../models/note_recording_holder.dart';
import '../../models/project.dart';
import '../../models/theme_item.dart';
import '../../models/development.dart';
import '../../models/status_change.dart';
import '../../services/firestore_service.dart';
import '../../services/note_recording_storage.dart';
import '../../utils/firestore_messages.dart';
import '../../utils/user_display.dart';
import '../../widgets/entity_notes_section.dart';
import '../../widgets/note_recording_editor.dart';
import '../../widgets/note_recording_playback.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/voice_dictation_text_field.dart';
import '../../widgets/history_entry_tile.dart';

class DevelopmentDetailScreen extends StatefulWidget {
  final String devId;
  final String devName;
  final ThemeItem theme;
  final Project project;

  const DevelopmentDetailScreen({
    super.key,
    required this.devId,
    required this.devName,
    required this.theme,
    required this.project,
  });

  @override
  State<DevelopmentDetailScreen> createState() => _DevelopmentDetailScreenState();
}

class _DevelopmentDetailScreenState extends State<DevelopmentDetailScreen> {
  late final FirestoreService _service;
  late final Stream<Development?> _devStream;
  late final Stream<List<StatusChange>> _historyStream;

  @override
  void initState() {
    super.initState();
    _service = FirestoreService();
    _devStream = _service.watchDevelopment(widget.devId);
    _historyStream = _service.getStatusHistory(widget.devId);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = firebaseUserDisplayLabel(user);

    return StreamBuilder<Development?>(
      stream: _devStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                widget.devName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  firestoreHistoryErrorHint(snapshot.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final dev = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dev?.name ?? widget.devName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${widget.project.name} › ${widget.theme.name}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            actions: [
              if (dev != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar',
                  onPressed: () => _showEditDialog(
                    context,
                    dev,
                    userId: user?.uid ?? '',
                    userName: userName,
                  ),
                ),
            ],
          ),
          body: dev == null
              ? const Center(child: CircularProgressIndicator())
              : _DevDetailBody(
                  dev: dev,
                  service: _service,
                  historyStream: _historyStream,
                  userId: user?.uid ?? '',
                  userName: userName,
                ),
        );
      },
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    Development dev, {
    required String userId,
    required String userName,
  }) async {
    final nameController = TextEditingController(text: dev.name);
    final descController = TextEditingController(text: dev.description);
    final recordingHolder = NoteRecordingHolder(originalUrl: dev.descriptionRecordingUrl);
    DevelopmentStatus status = dev.status;

    try {
      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('Editar Desenvolvimento'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
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
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Estado',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<DevelopmentStatus>(
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(4),
                        value: status,
                        items: DevelopmentStatus.values
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
                        NoteRecordingStorage.uploadDevelopmentNote(dev.id, f),
                  );
                  final updated = Development(
                    id: dev.id,
                    name: nameController.text.trim(),
                    description: descController.text.trim(),
                    descriptionRecordingUrl: audioUrl,
                    status: status,
                    themeId: dev.themeId,
                    projectId: dev.projectId,
                    createdBy: dev.createdBy,
                    createdByName: dev.createdByName,
                    createdAt: dev.createdAt,
                  );
                  await _service.updateDevelopment(
                    updated,
                    oldDev: dev,
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
    }
  }
}

class _DevDetailBody extends StatelessWidget {
  final Development dev;
  final FirestoreService service;
  final Stream<List<StatusChange>> historyStream;
  final String userId;
  final String userName;

  const _DevDetailBody({
    required this.dev,
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
        _InfoCard(dev: dev, fmt: fmt),
        const SizedBox(height: 20),
        EntityNotesSection(
          parent: JournalNoteParent.development,
          parentId: dev.id,
          service: service,
          userId: userId,
          userName: userName,
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
              children: changes.map((c) => HistoryEntryTile(change: c, fmt: fmt)).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Development dev;
  final DateFormat fmt;

  const _InfoCard({required this.dev, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final color = devStatusColor(dev.status);
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
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(Icons.code, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dev.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                StatusBadge(label: dev.status.label, color: color),
              ],
            ),
            if (dev.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(dev.description, style: TextStyle(color: Colors.grey[700])),
            ],
            NoteRecordingPlayback(downloadUrl: dev.descriptionRecordingUrl),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _auditRow(dev, fmt),
          ],
        ),
      ),
    );
  }

  Widget _auditRow(Development d, DateFormat f) {
    if (d.updatedBy != null && d.updatedAt != null) {
      final name = auditActorLabel(
        storedDisplayName: d.updatedByName,
        uidOrEmpty: d.updatedBy ?? '',
      );
      return _AuditRow(icon: Icons.edit, text: 'Editado por $name · ${f.format(d.updatedAt!)}');
    }
    final name = auditActorLabel(
      storedDisplayName: d.createdByName.isNotEmpty ? d.createdByName : null,
      uidOrEmpty: d.createdBy,
    );
    return _AuditRow(icon: Icons.person_add_alt, text: 'Criado por $name · ${f.format(d.createdAt)}');
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
          child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      ],
    );
  }
}
