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
  });

  factory Project.fromMap(Map<String, dynamic> map, String id) {
    final rawIde = map['ideCountingFolderFsPath'];
    final ide =
        rawIde is String ? rawIde.trim() : (rawIde is num ? '$rawIde' : '').trim();
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      if (descriptionRecordingUrl != null) 'descriptionRecordingUrl': descriptionRecordingUrl,
      'status': status.key,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt,
      if (updatedBy != null) 'updatedBy': updatedBy,
      if (updatedByName != null) 'updatedByName': updatedByName,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (ideCountingFolderFsPath.trim().isNotEmpty)
        'ideCountingFolderFsPath': ideCountingFolderFsPath.trim(),
    };
  }
}
