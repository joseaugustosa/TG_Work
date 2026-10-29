import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/note_recording_holder.dart';
import '../../models/project.dart';
import '../../services/firestore_service.dart';
import '../../services/note_recording_storage.dart';
import '../../utils/ide_workspace_path_pick.dart';
import '../../utils/user_display.dart';
import '../../utils/windows_firestore_compat.dart';
import '../../utils/kanban_time_summary.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/note_recording_editor.dart';
import '../../models/app_user.dart';
import '../../widgets/project_classification_fields.dart';
import '../../widgets/project_people_fields.dart';
import '../../widgets/project_status_picker.dart';
import '../../widgets/status_history_sheet.dart';
import '../../widgets/status_kanban_board.dart';
import '../../widgets/voice_dictation_text_field.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool _kanban = false;
  String? _filterTypeId;
  String? _filterAreaId;
  String? _filterSubtypeId;

  late final FirestoreService _service;
  late final Stream<List<Project>> _projectsStream;
  late final Stream<Map<String, DateTime>> _execDatesStream;

  @override
  void initState() {
    super.initState();
    _service = FirestoreService();
    _projectsStream = _service.getProjects();
    _execDatesStream = _service.watchProjectFirstExecutionDateMap();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _changeStatus(
    Project project, {
    required String userId,
    required String userName,
  }) async {
    final next = await showProjectStatusPicker(
      context,
      current: project.status,
    );
    if (next == null || next == project.status) return;
    await _service.changeProjectStatus(
      project,
      newStatus: next,
      userId: userId,
      userName: userName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = firebaseUserDisplayLabel(user);
    final showKanbanUi = !firestoreWorkloadReduceOnDesktop;
    final useKanbanBoard = showKanbanUi && _kanban;

    return StreamBuilder<Map<String, DateTime>>(
      stream: _execDatesStream,
      initialData: const {},
      builder: (context, execSnap) {
        final execDates = execSnap.data ?? {};
        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ProjectClassificationFilters(
                      service: _service,
                      typeId: _filterTypeId,
                      areaId: _filterAreaId,
                      subtypeId: _filterSubtypeId,
                      onTypeChanged: (v) => setState(() {
                        _filterTypeId = v;
                        _filterAreaId = null;
                        _filterSubtypeId = null;
                      }),
                      onAreaChanged: (v) => setState(() {
                        _filterAreaId = v;
                        _filterSubtypeId = null;
                      }),
                      onSubtypeChanged: (v) =>
                          setState(() => _filterSubtypeId = v),
                    ),
                    const SizedBox(height: 8),
                    showKanbanUi
                        ? Align(
                            alignment: Alignment.centerRight,
                            child: SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment<bool>(
                                  value: false,
                                  label: Text('Lista'),
                                  icon: Icon(Icons.view_list_outlined, size: 18),
                                ),
                                ButtonSegment<bool>(
                                  value: true,
                                  label: Text('Kanban'),
                                  icon:
                                      Icon(Icons.view_kanban_outlined, size: 18),
                                ),
                              ],
                              selected: {_kanban},
                              onSelectionChanged: (s) =>
                                  setState(() => _kanban = s.first),
                              style: ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                foregroundColor:
                                    WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return const Color(0xFF1A237E);
                                  }
                                  return Colors.grey[700];
                                }),
                              ),
                            ),
                          )
                        : Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                'Lista (Kanban só neste momento em Android / iOS)',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[700]),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<AppUser?>(
                  stream: _service.watchAppUser(user?.uid ?? ''),
                  builder: (context, meSnap) {
                    final me = meSnap.data;
                    return StreamBuilder<List<Project>>(
                  stream: _projectsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Erro: ${snapshot.error}'));
                    }
                    var allProjects = snapshot.data ?? [];
                    if (me == null) {
                      allProjects = [];
                    } else if (!me.isAdmin) {
                      allProjects = allProjects
                          .where((p) => me.canSeeProject(p.id))
                          .toList();
                    }
                    final projects = filterProjectsByClassification(
                      allProjects,
                      typeId: _filterTypeId,
                      areaId: _filterAreaId,
                      subtypeId: _filterSubtypeId,
                    );
                    if (allProjects.isEmpty) {
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
                    if (projects.isEmpty) {
                      return Center(
                        child: Text(
                          'Nenhum projeto com este tipo / subtipo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[700], fontSize: 15),
                        ),
                      );
                    }
                    if (useKanbanBoard) {
                      return StatusKanbanBoard<Project, ProjectStatus>(
                        columns: ProjectStatus.values,
                        labelOf: (s) => s.label,
                        colorOf: projectStatusColor,
                        statusOf: (p) => p.status,
                        items: projects,
                        columnWidth: 300,
                        onItemMoved: (project, status) async {
                          if (project.status == status) return;
                          await _service.changeProjectStatus(
                            project,
                            newStatus: status,
                            userId: user?.uid ?? '',
                            userName: userName,
                          );
                        },
                        cardBuilder: (context, project) {
                          final classLabel = project.classificationLabel;
                          final done = project.status == ProjectStatus.concluido;
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProjectDetailScreen(
                                    projectId: project.id,
                                    projectName: project.name,
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
                                          backgroundColor: const Color(0xFF1A237E)
                                              .withValues(alpha: 0.12),
                                          child: Icon(
                                            done
                                                ? Icons.check_circle_outline
                                                : Icons.folder_outlined,
                                            color: const Color(0xFF1A237E),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            project.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              decoration: done
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                              color: done
                                                  ? Colors.grey[600]
                                                  : null,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          onSelected: (value) async {
                                            if (value == 'status') {
                                              await _changeStatus(
                                                project,
                                                userId: user?.uid ?? '',
                                                userName: userName,
                                              );
                                            } else if (value == 'edit') {
                                              _showProjectDialog(
                                                context,
                                                _service,
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
                                              await _service
                                                  .deleteProject(project.id);
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(
                                              value: 'status',
                                              child: Text('Mudar estado'),
                                            ),
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Editar'),
                                            ),
                                            const PopupMenuItem(
                                              value: 'history',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.history,
                                                      size: 18, color: Colors.grey),
                                                  SizedBox(width: 8),
                                                  Text('Histórico'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Eliminar'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (classLabel.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        classLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                    if (project.peopleLabel.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        project.peopleLabel,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                    if (project.description.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        project.description,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: InkWell(
                                        onTap: () => _changeStatus(
                                          project,
                                          userId: user?.uid ?? '',
                                          userName: userName,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        child: StatusBadge(
                                          label: project.status.label,
                                          color:
                                              projectStatusColor(project.status),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      kanbanTimeSummaryPt(
                                        createdAt: project.createdAt,
                                        updatedAt: project.updatedAt,
                                        isDone: project.status.isTerminal,
                                        isExequivel:
                                            project.status == ProjectStatus.exequivel,
                                        isPausa:
                                            project.status == ProjectStatus.pausa,
                                        execSinceDate: execDates[project.id],
                                        pausedAt: project.pausedAt,
                                        totalPausedMs: project.totalPausedMs,
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
                      itemCount: projects.length,
                      itemBuilder: (context, index) {
                        final project = projects[index];
                        final classLabel = project.classificationLabel;
                        final done = project.status == ProjectStatus.concluido;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor:
                                  const Color(0xFF1A237E).withValues(alpha: 0.1),
                              child: Icon(
                                done
                                    ? Icons.check_circle_outline
                                    : Icons.folder,
                                color: const Color(0xFF1A237E),
                              ),
                            ),
                            title: Text(
                              project.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration:
                                    done ? TextDecoration.lineThrough : null,
                                color: done ? Colors.grey[600] : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (classLabel.isNotEmpty)
                                  Text(
                                    classLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (project.peopleLabel.isNotEmpty)
                                  Text(
                                    project.peopleLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                if (project.description.isNotEmpty)
                                  Text(project.description),
                                _AuditLine(project: project),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => _changeStatus(
                                    project,
                                    userId: user?.uid ?? '',
                                    userName: userName,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  child: StatusBadge(
                                    label: project.status.label,
                                    color: projectStatusColor(project.status),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'status') {
                                      await _changeStatus(
                                        project,
                                        userId: user?.uid ?? '',
                                        userName: userName,
                                      );
                                    } else if (value == 'edit') {
                                      _showProjectDialog(
                                        context,
                                        _service,
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
                                      await _service.deleteProject(project.id);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'status',
                                      child: Text('Mudar estado'),
                                    ),
                                    const PopupMenuItem(
                                        value: 'edit', child: Text('Editar')),
                                    const PopupMenuItem(
                                      value: 'history',
                                      child: Row(
                                        children: [
                                          Icon(Icons.history,
                                              size: 18, color: Colors.grey),
                                          SizedBox(width: 8),
                                          Text('Histórico'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                        value: 'delete', child: Text('Eliminar')),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProjectDetailScreen(
                                  projectId: project.id,
                                  projectName: project.name,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            onPressed: () => _showProjectDialog(
              context,
              _service,
              userId: user?.uid ?? '',
              userName: userName,
            ),
            child: const Icon(Icons.add),
          ),
        );
      },
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
    final idePathController =
        TextEditingController(text: project?.ideCountingFolderFsPath ?? '');
    final recordingHolder = NoteRecordingHolder(originalUrl: project?.descriptionRecordingUrl);
    ProjectStatus status = project?.status ?? ProjectStatus.exequivel;
    String typeId = project?.projectTypeId ?? '';
    String typeName = project?.projectTypeName ?? '';
    String areaId = project?.projectAreaId ?? '';
    String areaName = project?.projectAreaName ?? '';
    String subtypeId = project?.projectSubtypeId ?? '';
    String subtypeName = project?.projectSubtypeName ?? '';
    String responsibleId = project?.responsibleUserId ?? '';
    String responsibleName = project?.responsibleUserName ?? '';
    var intervenientIds = List<String>.from(project?.intervenientUserIds ?? const []);
    var intervenientNames =
        List<String>.from(project?.intervenientUserNames ?? const []);

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
                ProjectClassificationFields(
                  service: service,
                  typeId: typeId.isEmpty ? null : typeId,
                  areaId: areaId.isEmpty ? null : areaId,
                  subtypeId: subtypeId.isEmpty ? null : subtypeId,
                  onTypeChanged: (t) => setState(() {
                    typeId = t?.id ?? '';
                    typeName = t?.name ?? '';
                    areaId = '';
                    areaName = '';
                    subtypeId = '';
                    subtypeName = '';
                  }),
                  onAreaChanged: (a) => setState(() {
                    areaId = a?.id ?? '';
                    areaName = a?.name ?? '';
                    subtypeId = '';
                    subtypeName = '';
                  }),
                  onSubtypeChanged: (s) => setState(() {
                    subtypeId = s?.id ?? '';
                    subtypeName = s?.name ?? '';
                  }),
                ),
                const SizedBox(height: 12),
                ProjectPeopleFields(
                  service: service,
                  responsibleUserId: responsibleId,
                  intervenientUserIds: intervenientIds,
                  onResponsibleChanged: (AppUser? u) => setState(() {
                    responsibleId = u?.id ?? '';
                    responsibleName =
                        u == null ? '' : ProjectPeopleFields.labelOf(u);
                    if (u != null) {
                      final i = intervenientIds.indexOf(u.id);
                      if (i >= 0) {
                        intervenientIds = List<String>.from(intervenientIds)
                          ..removeAt(i);
                        intervenientNames =
                            List<String>.from(intervenientNames)..removeAt(i);
                      }
                    }
                  }),
                  onIntervenientsChanged: (list) => setState(() {
                    intervenientIds = list.map((u) => u.id).toList();
                    intervenientNames =
                        list.map(ProjectPeopleFields.labelOf).toList();
                  }),
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
                              'pela pasta aberta (se coincidir com o guardado aqui/Firestore) ou pelo nome da pasta '
                              '(único). Ou escolhes o caminho ao lado.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Escolher pasta ou ficheiro…',
                      onPressed: () async {
                        if (kIsWeb) {
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Na Web não há acesso aos ficheiros do teu PC. '
                                'Escreve o caminho ou usa a app no Windows/Android.',
                              ),
                            ),
                          );
                          return;
                        }
                        final p =
                            await pickIdeWorkspaceFilesystemPath(context);
                        if (p != null && context.mounted) {
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
                final base = Project(
                  id: project?.id ?? '',
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  status: status,
                  ideCountingFolderFsPath: idePathController.text.trim(),
                  createdBy: project?.createdBy ?? userId,
                  createdByName: project?.createdByName ?? userName,
                  createdAt: project?.createdAt ?? DateTime.now(),
                  projectTypeId: typeId,
                  projectTypeName: typeName,
                  projectAreaId: areaId,
                  projectAreaName: areaName,
                  projectSubtypeId: subtypeId,
                  projectSubtypeName: subtypeName,
                  responsibleUserId: responsibleId,
                  responsibleUserName: responsibleName,
                  intervenientUserIds: intervenientIds,
                  intervenientUserNames: intervenientNames,
                );
                if (project == null) {
                  final newId = await service.addProject(
                    base,
                    userId: userId,
                    userName: userName,
                  );
                  final added = base.copyWith(id: newId);
                  final audioUrl = await NoteRecordingStorage.resolveOnSave(
                    holder: recordingHolder,
                    uploadPending: (f) => NoteRecordingStorage.uploadProjectNote(newId, f),
                  );
                  if (audioUrl != null) {
                    await service.updateProject(
                      added.copyWith(descriptionRecordingUrl: audioUrl),
                      oldProject: added,
                      userId: userId,
                      userName: userName,
                    );
                  }
                } else {
                  final audioUrl = await NoteRecordingStorage.resolveOnSave(
                    holder: recordingHolder,
                    uploadPending: (f) => NoteRecordingStorage.uploadProjectNote(project.id, f),
                  );
                  await service.updateProject(
                    base.copyWith(
                      id: project.id,
                      descriptionRecordingUrl: audioUrl,
                    ),
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
    ).whenComplete(() {
      nameController.dispose();
      descController.dispose();
      idePathController.dispose();
    });
  }
}

class _AuditLine extends StatelessWidget {
  final Project project;

  const _AuditLine({required this.project});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yy HH:mm');
    if (project.updatedBy != null && project.updatedAt != null) {
      final name = auditActorLabel(
        storedDisplayName: project.updatedByName,
        uidOrEmpty: project.updatedBy ?? '',
      );
      return Text(
        'Atualizado por $name · ${fmt.format(project.updatedAt!)}',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      );
    }
    if (project.createdBy.isNotEmpty || project.createdByName.isNotEmpty) {
      final name = auditActorLabel(
        storedDisplayName:
            project.createdByName.isNotEmpty ? project.createdByName : null,
        uidOrEmpty: project.createdBy,
      );
      return Text(
        'Criado por $name · ${fmt.format(project.createdAt)}',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      );
    }
    return const SizedBox.shrink();
  }
}
