import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/note_recording_holder.dart';
import '../../models/project.dart';
import '../../models/theme_item.dart';
import '../../services/firestore_service.dart';
import '../../services/note_recording_storage.dart';
import '../../utils/user_display.dart';
import '../../utils/windows_firestore_compat.dart';
import '../../utils/kanban_time_summary.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/note_recording_editor.dart';
import '../../widgets/status_history_sheet.dart';
import '../../widgets/status_kanban_board.dart';
import '../../widgets/voice_dictation_text_field.dart';
import 'theme_detail_screen.dart';

class ThemesScreen extends StatefulWidget {
  final Project project;

  const ThemesScreen({super.key, required this.project});

  @override
  State<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State<ThemesScreen> {
  bool _kanban = false;

  late final FirestoreService _service;
  late final Stream<List<ThemeItem>> _themesStream;

  @override
  void initState() {
    super.initState();
    _service = FirestoreService();
    _themesStream = _service.getThemes(widget.project.id);
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final user = FirebaseAuth.instance.currentUser;
    final userName = firebaseUserDisplayLabel(user);
    final showKanbanToggle = !firestoreWorkloadReduceOnDesktop;
    final useKanbanBoard = showKanbanToggle && _kanban;

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
        actions: [
          if (showKanbanToggle)
            IconButton(
              icon: Icon(_kanban ? Icons.view_list_outlined : Icons.view_kanban_outlined),
              tooltip: _kanban ? 'Ver lista' : 'Ver Kanban',
              onPressed: () => setState(() => _kanban = !_kanban),
            ),
        ],
      ),
      body: StreamBuilder<List<ThemeItem>>(
        stream: _themesStream,
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
          if (useKanbanBoard) {
            return StatusKanbanBoard<ThemeItem, ThemeStatus>(
              columns: ThemeStatus.values,
              labelOf: (s) => s.label,
              colorOf: themeStatusColor,
              statusOf: (t) => t.status,
              items: themes,
              columnWidth: 272,
              onItemMoved: (theme, status) async {
                if (theme.status == status) return;
                await _service.updateTheme(
                  ThemeItem(
                    id: theme.id,
                    name: theme.name,
                    description: theme.description,
                    descriptionRecordingUrl: theme.descriptionRecordingUrl,
                    status: status,
                    projectId: theme.projectId,
                    createdBy: theme.createdBy,
                    createdByName: theme.createdByName,
                    createdAt: theme.createdAt,
                  ),
                  oldTheme: theme,
                  userId: user?.uid ?? '',
                  userName: userName,
                );
              },
              cardBuilder: (context, theme) {
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
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
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    themeStatusColor(theme.status).withValues(alpha: 0.15),
                                child: Icon(Icons.topic, color: themeStatusColor(theme.status)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  theme.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    _showThemeDialog(
                                      context,
                                      _service,
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
                                    await _service.deleteTheme(theme.id);
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
                          if (theme.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              theme.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            ),
                          ],
                          const SizedBox(height: 10),
                          StatusBadge(
                            label: theme.status.label,
                            color: themeStatusColor(theme.status),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            kanbanTimeSummaryPt(
                              createdAt: theme.createdAt,
                              updatedAt: theme.updatedAt,
                              isDone: theme.status == ThemeStatus.feito,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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
                              _service,
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
                            await _service.deleteTheme(theme.id);
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
          _service,
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
    final recordingHolder = NoteRecordingHolder(originalUrl: theme?.descriptionRecordingUrl);
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
                          .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
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
                onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final base = ThemeItem(
                  id: theme?.id ?? '',
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  status: status,
                  projectId: widget.project.id,
                  createdBy: theme?.createdBy ?? userId,
                  createdByName: theme?.createdByName ?? userName,
                  createdAt: theme?.createdAt ?? DateTime.now(),
                );
                if (theme == null) {
                  final newId = await service.addTheme(
                    base,
                    userId: userId,
                    userName: userName,
                  );
                  final added = ThemeItem(
                    id: newId,
                    name: base.name,
                    description: base.description,
                    status: base.status,
                    projectId: base.projectId,
                    createdBy: base.createdBy,
                    createdByName: base.createdByName,
                    createdAt: base.createdAt,
                  );
                  final audioUrl = await NoteRecordingStorage.resolveOnSave(
                    holder: recordingHolder,
                    uploadPending: (f) => NoteRecordingStorage.uploadThemeNote(newId, f),
                  );
                  if (audioUrl != null) {
                    await service.updateTheme(
                      ThemeItem(
                        id: newId,
                        name: added.name,
                        description: added.description,
                        descriptionRecordingUrl: audioUrl,
                        status: added.status,
                        projectId: added.projectId,
                        createdBy: added.createdBy,
                        createdByName: added.createdByName,
                        createdAt: added.createdAt,
                      ),
                      oldTheme: added,
                      userId: userId,
                      userName: userName,
                    );
                  }
                } else {
                  final audioUrl = await NoteRecordingStorage.resolveOnSave(
                    holder: recordingHolder,
                    uploadPending: (f) => NoteRecordingStorage.uploadThemeNote(theme.id, f),
                  );
                  await service.updateTheme(
                    ThemeItem(
                      id: theme.id,
                      name: base.name,
                      description: base.description,
                      descriptionRecordingUrl: audioUrl,
                      status: base.status,
                      projectId: base.projectId,
                      createdBy: base.createdBy,
                      createdByName: base.createdByName,
                      createdAt: base.createdAt,
                    ),
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
    ).whenComplete(() {
      nameController.dispose();
      descController.dispose();
    });
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
