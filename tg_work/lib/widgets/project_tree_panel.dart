import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/development.dart';
import '../models/journal_note.dart';
import '../models/project.dart';
import '../models/theme_item.dart';
import '../services/firestore_service.dart';
import '../utils/user_display.dart';
import 'status_badge.dart';

/// Painel reutilizável: árvore Projeto → Temas → Desenvolvimentos → Notas,
/// com caixas de verificação de conclusão / execução.
class ProjectTreePanel extends StatefulWidget {
  final Project project;
  final bool initiallyExpanded;
  final EdgeInsetsGeometry padding;

  const ProjectTreePanel({
    super.key,
    required this.project,
    this.initiallyExpanded = true,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<ProjectTreePanel> createState() => _ProjectTreePanelState();
}

class _ProjectTreePanelState extends State<ProjectTreePanel> {
  late final FirestoreService _service;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _service = FirestoreService();
  }

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _userName =>
      firebaseUserDisplayLabel(FirebaseAuth.instance.currentUser);

  Future<void> _runBusy(String key, Future<void> Function() fn) async {
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try {
      await fn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _toggleProject(Project project, bool done) async {
    await _runBusy('p:${project.id}', () async {
      final next = Project(
        id: project.id,
        name: project.name,
        description: project.description,
        descriptionRecordingUrl: project.descriptionRecordingUrl,
        status: done ? ProjectStatus.concluido : ProjectStatus.emExecucao,
        createdBy: project.createdBy,
        createdByName: project.createdByName,
        createdAt: project.createdAt,
        ideCountingFolderFsPath: project.ideCountingFolderFsPath,
      );
      await _service.updateProject(
        next,
        oldProject: project,
        userId: _uid,
        userName: _userName,
      );
    });
  }

  Future<void> _toggleTheme(ThemeItem theme, bool done) async {
    await _runBusy('t:${theme.id}', () async {
      final next = ThemeItem(
        id: theme.id,
        name: theme.name,
        description: theme.description,
        descriptionRecordingUrl: theme.descriptionRecordingUrl,
        status: done ? ThemeStatus.feito : ThemeStatus.emAndamento,
        projectId: theme.projectId,
        createdBy: theme.createdBy,
        createdByName: theme.createdByName,
        createdAt: theme.createdAt,
      );
      await _service.updateTheme(
        next,
        oldTheme: theme,
        userId: _uid,
        userName: _userName,
      );
    });
  }

  Future<void> _toggleDev(Development dev, bool done) async {
    await _runBusy('d:${dev.id}', () async {
      final next = Development(
        id: dev.id,
        name: dev.name,
        description: dev.description,
        descriptionRecordingUrl: dev.descriptionRecordingUrl,
        status: done ? DevelopmentStatus.feito : DevelopmentStatus.emAndamento,
        themeId: dev.themeId,
        projectId: dev.projectId,
        createdBy: dev.createdBy,
        createdByName: dev.createdByName,
        createdAt: dev.createdAt,
      );
      await _service.updateDevelopment(
        next,
        oldDev: dev,
        userId: _uid,
        userName: _userName,
      );
    });
  }

  Future<void> _toggleNote({
    required JournalNoteParent parent,
    required String parentId,
    required JournalNote note,
    required bool done,
  }) async {
    await _runBusy('n:${note.id}', () async {
      await _service.setJournalNoteDone(
        parent: parent,
        parentId: parentId,
        noteId: note.id,
        done: done,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: _service.watchProject(widget.project.id),
      builder: (context, pSnap) {
        final project = pSnap.data ?? widget.project;
        return StreamBuilder<List<ThemeItem>>(
          stream: _service.getThemes(project.id),
          builder: (context, tSnap) {
            final themes = tSnap.data ?? [];
            return StreamBuilder<List<Development>>(
              stream: _service.getDevelopmentsByProject(project.id),
              builder: (context, dSnap) {
                final allDevs = dSnap.data ?? [];
                final byTheme = <String, List<Development>>{};
                for (final d in allDevs) {
                  byTheme.putIfAbsent(d.themeId, () => []).add(d);
                }

                final projectDone = project.status == ProjectStatus.concluido;

                return Padding(
                  padding: widget.padding,
                  child: Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ExpansionTile(
                      initiallyExpanded: widget.initiallyExpanded,
                      leading: Checkbox(
                        value: projectDone,
                        onChanged: _uid.isEmpty
                            ? null
                            : (v) => _toggleProject(project, v == true),
                      ),
                      title: Text(
                        project.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration: projectDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          StatusBadge(
                            label: project.status.label,
                            color: projectStatusColor(project.status),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${themes.length} tema(s) · ${allDevs.length} desenvolvimento(s)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      children: [
                        _NotesBranch(
                          parent: JournalNoteParent.project,
                          parentId: project.id,
                          service: _service,
                          busy: _busy,
                          onToggle: (note, done) => _toggleNote(
                            parent: JournalNoteParent.project,
                            parentId: project.id,
                            note: note,
                            done: done,
                          ),
                        ),
                        if (themes.isEmpty)
                          const ListTile(
                            dense: true,
                            title: Text('Sem temas neste projeto.'),
                          ),
                        for (final theme in themes)
                          _ThemeBranch(
                            theme: theme,
                            developments: byTheme[theme.id] ?? const [],
                            service: _service,
                            busy: _busy,
                            onToggleTheme: (done) => _toggleTheme(theme, done),
                            onToggleDev: _toggleDev,
                            onToggleNote: _toggleNote,
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ThemeBranch extends StatelessWidget {
  final ThemeItem theme;
  final List<Development> developments;
  final FirestoreService service;
  final Set<String> busy;
  final Future<void> Function(bool done) onToggleTheme;
  final Future<void> Function(Development dev, bool done) onToggleDev;
  final Future<void> Function({
    required JournalNoteParent parent,
    required String parentId,
    required JournalNote note,
    required bool done,
  }) onToggleNote;

  const _ThemeBranch({
    required this.theme,
    required this.developments,
    required this.service,
    required this.busy,
    required this.onToggleTheme,
    required this.onToggleDev,
    required this.onToggleNote,
  });

  @override
  Widget build(BuildContext context) {
    final done = theme.status == ThemeStatus.feito;
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: ExpansionTile(
        controlAffinity: ListTileControlAffinity.trailing,
        leading: Checkbox(
          value: done,
          onChanged: busy.contains('t:${theme.id}')
              ? null
              : (v) => onToggleTheme(v == true),
        ),
        title: Text(
          theme.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: done ? TextDecoration.lineThrough : null,
            color: done ? Colors.grey.shade600 : null,
          ),
        ),
        subtitle: Row(
          children: [
            StatusBadge(
              label: theme.status.label,
              color: themeStatusColor(theme.status),
            ),
            const SizedBox(width: 8),
            Text(
              '${developments.length} desenvolvimento(s)',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
            ),
          ],
        ),
        children: [
          _NotesBranch(
            parent: JournalNoteParent.theme,
            parentId: theme.id,
            service: service,
            busy: busy,
            indent: 8,
            onToggle: (note, d) => onToggleNote(
              parent: JournalNoteParent.theme,
              parentId: theme.id,
              note: note,
              done: d,
            ),
          ),
          if (developments.isEmpty)
            const ListTile(
              dense: true,
              contentPadding: EdgeInsets.only(left: 48),
              title: Text('Sem desenvolvimentos.'),
            ),
          for (final dev in developments)
            _DevBranch(
              dev: dev,
              service: service,
              busy: busy,
              onToggleDev: onToggleDev,
              onToggleNote: onToggleNote,
            ),
        ],
      ),
    );
  }
}

class _DevBranch extends StatelessWidget {
  final Development dev;
  final FirestoreService service;
  final Set<String> busy;
  final Future<void> Function(Development dev, bool done) onToggleDev;
  final Future<void> Function({
    required JournalNoteParent parent,
    required String parentId,
    required JournalNote note,
    required bool done,
  }) onToggleNote;

  const _DevBranch({
    required this.dev,
    required this.service,
    required this.busy,
    required this.onToggleDev,
    required this.onToggleNote,
  });

  @override
  Widget build(BuildContext context) {
    final done = dev.status == DevelopmentStatus.feito;
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: ExpansionTile(
        controlAffinity: ListTileControlAffinity.trailing,
        leading: Checkbox(
          value: done,
          onChanged: busy.contains('d:${dev.id}')
              ? null
              : (v) => onToggleDev(dev, v == true),
        ),
        title: Text(
          dev.name,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            decoration: done ? TextDecoration.lineThrough : null,
            color: done ? Colors.grey.shade600 : null,
          ),
        ),
        subtitle: StatusBadge(
          label: dev.status.label,
          color: devStatusColor(dev.status),
        ),
        children: [
          _NotesBranch(
            parent: JournalNoteParent.development,
            parentId: dev.id,
            service: service,
            busy: busy,
            indent: 16,
            onToggle: (note, d) => onToggleNote(
              parent: JournalNoteParent.development,
              parentId: dev.id,
              note: note,
              done: d,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesBranch extends StatelessWidget {
  final JournalNoteParent parent;
  final String parentId;
  final FirestoreService service;
  final Set<String> busy;
  final double indent;
  final Future<void> Function(JournalNote note, bool done) onToggle;

  const _NotesBranch({
    required this.parent,
    required this.parentId,
    required this.service,
    required this.busy,
    required this.onToggle,
    this.indent = 0,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JournalNote>>(
      stream: service.watchJournalNotes(parent, parentId),
      builder: (context, snap) {
        final notes = snap.data ?? [];
        if (notes.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(left: 48 + indent, bottom: 4),
            child: Text(
              'Sem notas',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade500,
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 40 + indent, top: 4, bottom: 2),
              child: Text(
                'Notas (conclusão)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            for (final note in notes)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.only(left: 28 + indent, right: 12),
                controlAffinity: ListTileControlAffinity.leading,
                value: note.done,
                onChanged: busy.contains('n:${note.id}')
                    ? null
                    : (v) => onToggle(note, v == true),
                title: SelectableText(
                  note.text.trim().isEmpty
                      ? '(nota sem texto${note.recordingUrl != null ? ' · áudio' : ''})'
                      : note.text,
                  maxLines: 3,
                  style: TextStyle(
                    fontSize: 13,
                    decoration: note.done ? TextDecoration.lineThrough : null,
                    color: note.done ? Colors.grey.shade600 : null,
                  ),
                ),
                secondary: note.recordingUrl != null
                    ? Icon(Icons.mic, size: 16, color: Colors.grey.shade600)
                    : null,
              ),
          ],
        );
      },
    );
  }
}
