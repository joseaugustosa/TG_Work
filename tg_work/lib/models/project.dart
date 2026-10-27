import 'package:cloud_firestore/cloud_firestore.dart';

/// Ordem: fluxo típico no Kanban (exequível → em execução → concluído | não exequível).
enum ProjectStatus { exequivel, emExecucao, concluido, naoExequivel }

extension ProjectStatusExtension on ProjectStatus {
  String get label {
    switch (this) {
      case ProjectStatus.exequivel:
        return 'Exequível';
      case ProjectStatus.emExecucao:
        return 'Em execução';
      case ProjectStatus.concluido:
        return 'Concluído';
      case ProjectStatus.naoExequivel:
        return 'Não Exequível';
    }
  }

  String get key {
    switch (this) {
      case ProjectStatus.exequivel:
        return 'exequivel';
      case ProjectStatus.emExecucao:
        return 'emExecucao';
      case ProjectStatus.concluido:
        return 'concluido';
      case ProjectStatus.naoExequivel:
        return 'naoExequivel';
    }
  }
}

ProjectStatus projectStatusFromKey(String key) {
  switch (key) {
    case 'emExecucao':
      return ProjectStatus.emExecucao;
    case 'concluido':
      return ProjectStatus.concluido;
    case 'naoExequivel':
      return ProjectStatus.naoExequivel;
    default:
      return ProjectStatus.exequivel;
  }
}

class Project {
  final String id;
  final String name;
  final String description;
  /// URL no Firebase Storage (áudio da nota / descrição), opcional.
  final String? descriptionRecordingUrl;
  final ProjectStatus status;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final String? updatedBy;
  final String? updatedByName;
  final DateTime? updatedAt;

  /// Pasta (ou `.code-workspace`) no PC onde abres este projeto para a extensão IDE contabilizar sessão por abrir/fecho.
  final String ideCountingFolderFsPath;

  /// ID do tipo criado pelo utilizador (`project_types`).
  final String projectTypeId;

  /// Nome do tipo (cópia para listagens sem join).
  final String projectTypeName;

  /// ID da área (`project_areas`).
  final String projectAreaId;

  /// Nome da área (cópia para listagens).
  final String projectAreaName;

  /// ID do subtipo (`project_subtypes`).
  final String projectSubtypeId;

  /// Nome do subtipo (cópia para listagens).
  final String projectSubtypeName;

  /// Responsável pelo projeto (`app_users` / Auth uid).
  final String responsibleUserId;

  /// Nome do responsável (cópia para listagens).
  final String responsibleUserName;

  /// Intervenientes (uids).
  final List<String> intervenientUserIds;

  /// Nomes dos intervenientes (mesma ordem que [intervenientUserIds]).
  final List<String> intervenientUserNames;

  Project({
    required this.id,
    required this.name,
    required this.description,
    this.descriptionRecordingUrl,
    required this.status,
    required this.createdBy,
    this.createdByName = '',
    required this.createdAt,
    this.updatedBy,
    this.updatedByName,
    this.updatedAt,
    this.ideCountingFolderFsPath = '',
    this.projectTypeId = '',
    this.projectTypeName = '',
    this.projectAreaId = '',
    this.projectAreaName = '',
    this.projectSubtypeId = '',
    this.projectSubtypeName = '',
    this.responsibleUserId = '',
    this.responsibleUserName = '',
    this.intervenientUserIds = const [],
    this.intervenientUserNames = const [],
  });

  String get classificationLabel {
    final parts = <String>[
      projectTypeName.trim(),
      projectAreaName.trim(),
      projectSubtypeName.trim(),
    ].where((s) => s.isNotEmpty);
    return parts.join(' · ');
  }

  String get peopleLabel {
    final parts = <String>[];
    if (responsibleUserName.trim().isNotEmpty) {
      parts.add('Resp.: ${responsibleUserName.trim()}');
    }
    final ints = intervenientUserNames
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (ints.isNotEmpty) {
      parts.add('Int.: ${ints.join(', ')}');
    }
    return parts.join(' · ');
  }

  Project copyWith({
    String? id,
    String? name,
    String? description,
    String? descriptionRecordingUrl,
    bool clearDescriptionRecordingUrl = false,
    ProjectStatus? status,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    String? updatedBy,
    String? updatedByName,
    DateTime? updatedAt,
    String? ideCountingFolderFsPath,
    String? projectTypeId,
    String? projectTypeName,
    String? projectAreaId,
    String? projectAreaName,
    String? projectSubtypeId,
    String? projectSubtypeName,
    String? responsibleUserId,
    String? responsibleUserName,
    List<String>? intervenientUserIds,
    List<String>? intervenientUserNames,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      descriptionRecordingUrl: clearDescriptionRecordingUrl
          ? null
          : (descriptionRecordingUrl ?? this.descriptionRecordingUrl),
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedByName: updatedByName ?? this.updatedByName,
      updatedAt: updatedAt ?? this.updatedAt,
      ideCountingFolderFsPath:
          ideCountingFolderFsPath ?? this.ideCountingFolderFsPath,
      projectTypeId: projectTypeId ?? this.projectTypeId,
      projectTypeName: projectTypeName ?? this.projectTypeName,
      projectAreaId: projectAreaId ?? this.projectAreaId,
      projectAreaName: projectAreaName ?? this.projectAreaName,
      projectSubtypeId: projectSubtypeId ?? this.projectSubtypeId,
      projectSubtypeName: projectSubtypeName ?? this.projectSubtypeName,
      responsibleUserId: responsibleUserId ?? this.responsibleUserId,
      responsibleUserName: responsibleUserName ?? this.responsibleUserName,
      intervenientUserIds: intervenientUserIds ?? this.intervenientUserIds,
      intervenientUserNames:
          intervenientUserNames ?? this.intervenientUserNames,
    );
  }

  factory Project.fromMap(Map<String, dynamic> map, String id) {
    final rawIde = map['ideCountingFolderFsPath'];
    final ide =
        rawIde is String ? rawIde.trim() : (rawIde is num ? '$rawIde' : '').trim();
    // Compat: campos antigos `projectType` / `projectSubtype` como nomes.
    final typeId = (map['projectTypeId'] as String?)?.trim() ?? '';
    final typeName = (map['projectTypeName'] as String?)?.trim().isNotEmpty == true
        ? (map['projectTypeName'] as String).trim()
        : ((map['projectType'] as String?)?.trim() ?? '');
    final areaId = (map['projectAreaId'] as String?)?.trim() ?? '';
    final areaName = (map['projectAreaName'] as String?)?.trim() ?? '';
    final subtypeId = (map['projectSubtypeId'] as String?)?.trim() ?? '';
    final subtypeName =
        (map['projectSubtypeName'] as String?)?.trim().isNotEmpty == true
            ? (map['projectSubtypeName'] as String).trim()
            : ((map['projectSubtype'] as String?)?.trim() ?? '');
    List<String> readStringList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return Project(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      descriptionRecordingUrl: map['descriptionRecordingUrl'] as String?,
      status: projectStatusFromKey(map['status'] ?? ''),
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: map['updatedBy'],
      updatedByName: map['updatedByName'],
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      ideCountingFolderFsPath: ide,
      projectTypeId: typeId,
      projectTypeName: typeName,
      projectAreaId: areaId,
      projectAreaName: areaName,
      projectSubtypeId: subtypeId,
      projectSubtypeName: subtypeName,
      responsibleUserId: (map['responsibleUserId'] as String?)?.trim() ?? '',
      responsibleUserName:
          (map['responsibleUserName'] as String?)?.trim() ?? '',
      intervenientUserIds: readStringList(map['intervenientUserIds']),
      intervenientUserNames: readStringList(map['intervenientUserNames']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      if (descriptionRecordingUrl != null)
        'descriptionRecordingUrl': descriptionRecordingUrl,
      'status': status.key,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt,
      if (updatedBy != null) 'updatedBy': updatedBy,
      if (updatedByName != null) 'updatedByName': updatedByName,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (ideCountingFolderFsPath.trim().isNotEmpty)
        'ideCountingFolderFsPath': ideCountingFolderFsPath.trim(),
      if (projectTypeId.trim().isNotEmpty) 'projectTypeId': projectTypeId.trim(),
      if (projectTypeName.trim().isNotEmpty)
        'projectTypeName': projectTypeName.trim(),
      if (projectAreaId.trim().isNotEmpty) 'projectAreaId': projectAreaId.trim(),
      if (projectAreaName.trim().isNotEmpty)
        'projectAreaName': projectAreaName.trim(),
      if (projectSubtypeId.trim().isNotEmpty)
        'projectSubtypeId': projectSubtypeId.trim(),
      if (projectSubtypeName.trim().isNotEmpty)
        'projectSubtypeName': projectSubtypeName.trim(),
      'responsibleUserId': responsibleUserId.trim(),
      'responsibleUserName': responsibleUserName.trim(),
      'intervenientUserIds': intervenientUserIds
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'intervenientUserNames': intervenientUserNames
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    };
  }
}
