import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/journal_note.dart';
import '../models/note_recording_holder.dart';
import '../services/firestore_service.dart';
import '../services/note_recording_storage.dart';
import '../utils/firestore_messages.dart';
import '../utils/user_display.dart';
import 'note_recording_editor.dart';
import 'note_recording_playback.dart';
import 'voice_dictation_text_field.dart';

/// Lista de notas com autor e data; botão para nova nota (texto + ditado + gravação).
/// Stream do Firestore é criado uma vez por montagem para não martelar o SDK nativo no Windows.
class EntityNotesSection extends StatefulWidget {
  const EntityNotesSection({
    super.key,
    required this.parent,
    required this.parentId,
    required this.service,
    required this.userId,
    required this.userName,
  });

  final JournalNoteParent parent;
  final String parentId;
  final FirestoreService service;
  final String userId;
  final String userName;

  @override
  State<EntityNotesSection> createState() => _EntityNotesSectionState();
}

class _EntityNotesSectionState extends State<EntityNotesSection> {
  late Stream<List<JournalNote>> _notesStream;

  @override
  void initState() {
    super.initState();
    _notesStream = widget.service.watchJournalNotes(widget.parent, widget.parentId);
  }

  void _bindNotesStream() {
    _notesStream = widget.service.watchJournalNotes(widget.parent, widget.parentId);
  }

  @override
  void didUpdateWidget(covariant EntityNotesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parent != widget.parent ||
        oldWidget.parentId != widget.parentId ||
        !identical(oldWidget.service, widget.service)) {
      _bindNotesStream();
      setState(() {});
    }
  }

  String _effectiveUserId() {
    if (widget.userId.isNotEmpty) return widget.userId;
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  Future<void> _openAddDialog(BuildContext context) async {
    final uid = _effectiveUserId();
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sessão para criar notas.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => _AddJournalNoteDialog(
        parent: widget.parent,
        parentId: widget.parentId,
        service: widget.service,
        userId: uid,
        userName: widget.userName,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, JournalNote note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar nota'),
        content: const Text('Queres mesmo apagar esta nota?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await widget.service.deleteJournalNote(widget.parent, widget.parentId, note.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    final canEdit = _effectiveUserId().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Notas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: canEdit ? () => _openAddDialog(context) : null,
              icon: const Icon(Icons.note_add_outlined, size: 20),
              label: const Text('Nova nota'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        StreamBuilder<List<JournalNote>>(
          stream: _notesStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Erro ao carregar notas: ${firestoreJournalNotesErrorHint(snapshot.error)}',
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData &&
                snapshot.data == null) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final notes = snapshot.data ?? [];
            if (notes.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sticky_note_2_outlined, size: 40, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'Ainda não há notas. Usa «Nova nota» para escrever ou falar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: notes.map((n) => _JournalNoteCard(
                note: n,
                fmt: fmt,
                onDelete: canEdit ? () => _confirmDelete(context, n) : null,
              )).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _JournalNoteCard extends StatelessWidget {
  const _JournalNoteCard({
    required this.note,
    required this.fmt,
    this.onDelete,
  });

  final JournalNote note;
  final DateFormat fmt;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final author = auditActorLabel(
      storedDisplayName: note.createdByName.isNotEmpty ? note.createdByName : null,
      uidOrEmpty: note.createdBy,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: SelectableText(
                    '$author · ${fmt.format(note.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Apagar nota',
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (note.text.isNotEmpty)
              SelectableText(
                note.text,
                style: TextStyle(fontSize: 14, color: Colors.grey[900]),
              )
            else
              SelectableText(
                '(sem texto — só áudio)',
                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey[600]),
              ),
            NoteRecordingPlayback(downloadUrl: note.recordingUrl),
          ],
        ),
      ),
    );
  }
}

class _AddJournalNoteDialog extends StatefulWidget {
  const _AddJournalNoteDialog({
    required this.parent,
    required this.parentId,
    required this.service,
    required this.userId,
    required this.userName,
  });

  final JournalNoteParent parent;
  final String parentId;
  final FirestoreService service;
  final String userId;
  final String userName;

  @override
  State<_AddJournalNoteDialog> createState() => _AddJournalNoteDialogState();
}

class _AddJournalNoteDialogState extends State<_AddJournalNoteDialog> {
  final TextEditingController _text = TextEditingController();
  late final NoteRecordingHolder _recordingHolder = NoteRecordingHolder(originalUrl: null);
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final trimmed = _text.text.trim();
    if (trimmed.isEmpty && _recordingHolder.pendingLocalPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreve texto ou grava um áudio na nota.')),
      );
      return;
    }
    final uid = widget.userId.isNotEmpty
        ? widget.userId
        : (FirebaseAuth.instance.currentUser?.uid ?? '');
    if (uid.isEmpty) return;

    setState(() => _saving = true);
    try {
      final actor = normalizeStoredActorName(widget.userName);
      final note = JournalNote(
        id: '',
        text: trimmed,
        createdBy: uid,
        createdByName: actor,
        createdAt: DateTime.now(),
      );
      final noteId = await widget.service.addJournalNote(
        widget.parent,
        widget.parentId,
        note,
      );

      final url = await NoteRecordingStorage.resolveOnSave(
        holder: _recordingHolder,
        uploadPending: (f) => NoteRecordingStorage.uploadJournalNoteRecording(
          parent: widget.parent,
          parentId: widget.parentId,
          noteId: noteId,
          file: f,
        ),
      );
      if (url != null) {
        await widget.service.updateJournalNoteRecording(
          parent: widget.parent,
          parentId: widget.parentId,
          noteId: noteId,
          recordingUrl: url,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWin = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final intro = isWin
        ? 'No PC: usa «Falar para escrever» por baixo do texto para ditado (voz → texto). Podes também escrever à mão. «Gravar» / «Ouvir» é áudio em ficheiro (separado do ditado).'
        : 'Usa o microfone no campo para ditado (voz → texto) ou escreve à mão. Opcional: gravação de voz em ficheiro.';

    return AlertDialog(
      title: const Text('Nova nota'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              intro,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            VoiceDictationTextField(
              controller: _text,
              labelText: 'Texto da nota',
              maxLines: 6,
            ),
            const SizedBox(height: 16),
            NoteRecordingEditor(
              holder: _recordingHolder,
              onChanged: () => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
          ),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar nota'),
        ),
      ],
    );
  }
}
