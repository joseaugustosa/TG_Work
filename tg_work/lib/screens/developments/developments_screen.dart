import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/note_recording_holder.dart';
import '../../models/project.dart';
import '../../models/theme_item.dart';
import '../../models/development.dart';
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
import 'development_detail_screen.dart';

class DevelopmentsScreen extends StatefulWidget {
  final ThemeItem theme;
  final Project project;

  const DevelopmentsScreen({super.key, required this.theme, required this.project});

  @override
  State<DevelopmentsScreen> createState() => _DevelopmentsScreenState();
}

class _DevelopmentsScreenState extends State<DevelopmentsScreen> {
  bool _kanban = false;

  late final FirestoreService _service;
  late final Stream<List<Development>> _devsStream;

  @override
  void initState() {
    super.initState();
    _service = FirestoreService();
    _devsStream = _service.getDevelopments(widget.theme.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
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
            Text(theme.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Text('Desenvolvimentos',
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
      body: StreamBuilder<List<Development>>(
        stream: _devsStream,
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
          if (useKanbanBoard) {
            return StatusKanbanBoard<Development, DevelopmentStatus>(
              columns: DevelopmentStatus.values,
              labelOf: (s) => s.label,
              colorOf: devStatusColor,
              statusOf: (d) => d.status,
              items: devs,
              columnWidth: 248,
              onItemMoved: (dev, status) async {
                if (dev.status == status) return;
                await _service.updateDevelopment(
                  Development(
                    id: dev.id,
                    name: dev.name,
                    description: dev.description,
                    descriptionRecordingUrl: dev.descriptionRecordingUrl,
                    status: status,
                    themeId: dev.themeId,
                    projectId: dev.projectId,
                    createdBy: dev.createdBy,
                    createdByName: dev.createdByName,
                    createdAt: dev.createdAt,
                  ),
                  oldDev: dev,
                  userId: user?.uid ?? '',
                  userName: userName,
                );
              },
              cardBuilder: (context, dev) {
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
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
                                    devStatusColor(dev.status).withValues(alpha: 0.15),
                                child: Icon(Icons.code, color: devStatusColor(dev.status)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  dev.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    _showDevDialog(
                                      context,
                                      _service,
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
                                    await _service.deleteDevelopment(dev.id);
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
                          if (dev.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              dev.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            ),
                          ],
                          const SizedBox(height: 10),
                          StatusBadge(
                            label: dev.status.label,
                            color: devStatusColor(dev.status),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            kanbanTimeSummaryPt(
                              createdAt: dev.createdAt,
                              updatedAt: dev.updatedAt,
                              isDone: dev.status == DevelopmentStatus.feito ||
                                  dev.status == DevelopmentStatus.semEfeito ||
                                  dev.status == DevelopmentStatus.bom ||
                                  dev.status == DevelopmentStatus.podeMelhorar,
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
                              _service,
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
                            await _service.deleteDevelopment(dev.id);
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
          _service,
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
    final recordingHolder = NoteRecordingHolder(originalUrl: dev?.descriptionRecordingUrl);
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
                final base = Development(
                  id: dev?.id ?? '',
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  status: status,
                  themeId: widget.theme.id,
                  projectId: widget.project.id,
                  createdBy: dev?.createdBy ?? userId,
                  createdByName: dev?.createdByName ?? userName,
                  createdAt: dev?.createdAt ?? DateTime.now(),
                );
                if (dev == null) {
                  final newId = await service.addDevelopment(
                    base,
                    userId: userId,
                    userName: userName,
                  );
                  final added = Development(
                    id: newId,
                    name: base.name,
                    description: base.description,
                    status: base.status,
                    themeId: base.themeId,
                    projectId: base.projectId,
                    createdBy: base.createdBy,
                    createdByName: base.createdByName,
                    createdAt: base.createdAt,
                  );
                  final audioUrl = await NoteRecordingStorage.resolveOnSave(
                    holder: recordingHolder,
                    uploadPending: (f) => NoteRecordingStorage.uploadDevelopmentNote(newId, f),
                  );
                  if (audioUrl != null) {
                    await service.updateDevelopment(
                      Development(
                        id: newId,
                        name: added.name,
                        description: added.description,
                        descriptionRecordingUrl: audioUrl,
                        status: added.status,
                        themeId: added.themeId,
                        projectId: added.projectId,
                        createdBy: added.createdBy,
                        createdByName: added.createdByName,
                        createdAt: added.createdAt,
                      ),
                      oldDev: added,
                      userId: userId,
                      userName: userName,
                    );
                  }
                } else {
                  final audioUrl = await NoteRecordingStorage.resolveOnSave(
                    holder: recordingHolder,
                    uploadPending: (f) => NoteRecordingStorage.uploadDevelopmentNote(dev.id, f),
                  );
                  await service.updateDevelopment(
                    Development(
                      id: dev.id,
                      name: base.name,
                      description: base.description,
                      descriptionRecordingUrl: audioUrl,
                      status: base.status,
                      themeId: base.themeId,
                      projectId: base.projectId,
                      createdBy: base.createdBy,
                      createdByName: base.createdByName,
                      createdAt: base.createdAt,
                    ),
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
    ).whenComplete(() {
      nameController.dispose();
      descController.dispose();
    });
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
