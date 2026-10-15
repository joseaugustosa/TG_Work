import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/journal_note.dart';
import '../../models/note_recording_holder.dart';
import '../../models/project.dart';
import '../../models/theme_item.dart';
import '../../models/status_change.dart';
import '../../services/firestore_service.dart';
import '../../services/note_recording_storage.dart';
import '../../utils/firestore_messages.dart';
import '../../utils/user_display.dart';
import '../../widgets/entity_notes_section.dart';
import '../../widgets/note_recording_editor.dart';
import '../../widgets/note_recording_playback.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/history_entry_tile.dart';
import '../../widgets/voice_dictation_text_field.dart';
import '../developments/developments_screen.dart';

class ThemeDetailScreen extends StatefulWidget {
  final String themeId;
  final String themeName;
  final Project project;

  const ThemeDetailScreen({
    super.key,
    required this.themeId,
    required this.themeName,
    required this.project,
  });

  @override
  State<ThemeDetailScreen> createState() => _ThemeDetailScreenState();
}

class _ThemeDetailScreenState extends State<ThemeDetailScreen> {
  late final FirestoreService _service;
  late final Stream<ThemeItem?> _themeStream;
  late final Stream<List<StatusChange>> _historyStream;

  @override
  void initState() {
    super.initState();
    _service = FirestoreService();
    _themeStream = _service.watchTheme(widget.themeId);
    _historyStream = _service.getStatusHistory(widget.themeId);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = firebaseUserDisplayLabel(user);

    return StreamBuilder<ThemeItem?>(
      stream: _themeStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                widget.themeName,
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

        final theme = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  theme?.name ?? widget.themeName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                SelectableText(
                  widget.project.name,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            actions: [
              if (theme != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar',
                  onPressed: () => _showEditDialog(
                    context,
                    theme,
                    userId: user?.uid ?? '',
                    userName: userName,
                  ),
                ),
            ],
          ),
          body: theme == null
              ? const Center(child: CircularProgressIndicator())
              : _ThemeDetailBody(
                  theme: theme,
                  project: widget.project,
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
    ThemeItem theme, {
    required String userId,
    required String userName,
  }) async {
    final nameController = TextEditingController(text: theme.name);
    final descController = TextEditingController(text: theme.description);
    final recordingHolder = NoteRecordingHolder(originalUrl: theme.descriptionRecordingUrl);
    ThemeStatus status = theme.status;

    try {
      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('Editar Tema'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do tema',
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
                      child: DropdownButton<ThemeStatus>(
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(4),
                        value: status,
                        items: ThemeStatus.values
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
                        NoteRecordingStorage.uploadThemeNote(theme.id, f),
                  );
                  final updated = ThemeItem(
                    id: theme.id,
                    name: nameController.text.trim(),
                    description: descController.text.trim(),
                    descriptionRecordingUrl: audioUrl,
                    status: status,
                    projectId: theme.projectId,
                    createdBy: theme.createdBy,
                    createdByName: theme.createdByName,
                    createdAt: theme.createdAt,
                  );
                  await _service.updateTheme(
                    updated,
                    oldTheme: theme,
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

class _ThemeDetailBody extends StatelessWidget {
  final ThemeItem theme;
  final Project project;
  final FirestoreService service;
  final Stream<List<StatusChange>> historyStream;
  final String userId;
  final String userName;

  const _ThemeDetailBody({
    required this.theme,
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
        _InfoCard(theme: theme, fmt: fmt),
        const SizedBox(height: 20),
        EntityNotesSection(
          parent: JournalNoteParent.theme,
          parentId: theme.id,
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
          icon: const Icon(Icons.code_outlined),
          label: const Text('Ver Desenvolvimentos'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DevelopmentsScreen(theme: theme, project: project),
            ),
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
              children: changes.map((c) => HistoryEntryTile(change: c, fmt: fmt)).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final ThemeItem theme;
  final DateFormat fmt;

  const _InfoCard({required this.theme, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final color = themeStatusColor(theme.status);
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
                  child: Icon(Icons.topic, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectableText(
                    theme.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                StatusBadge(label: theme.status.label, color: color),
              ],
            ),
            if (theme.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(
                theme.description,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
            NoteRecordingPlayback(downloadUrl: theme.descriptionRecordingUrl),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _auditRow(theme, fmt),
          ],
        ),
      ),
    );
  }

  Widget _auditRow(ThemeItem t, DateFormat f) {
    if (t.updatedBy != null && t.updatedAt != null) {
      final name = auditActorLabel(
        storedDisplayName: t.updatedByName,
        uidOrEmpty: t.updatedBy ?? '',
      );
      return _AuditRow(icon: Icons.edit, text: 'Editado por $name · ${f.format(t.updatedAt!)}');
    }
    final name = auditActorLabel(
      storedDisplayName: t.createdByName.isNotEmpty ? t.createdByName : null,
      uidOrEmpty: t.createdBy,
    );
    return _AuditRow(icon: Icons.person_add_alt, text: 'Criado por $name · ${f.format(t.createdAt)}');
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
