import 'package:cloud_firestore/cloud_firestore.dart';

enum ProjectStatus { exequivel, naoExequivel }

extension ProjectStatusExtension on ProjectStatus {
  String get label {
    switch (this) {
      case ProjectStatus.exequivel:
        return 'Exequível';
      case ProjectStatus.naoExequivel:
        return 'Não Exequível';
    }
  }

  String get key {
    switch (this) {
      case ProjectStatus.exequivel:
        return 'exequivel';
      case ProjectStatus.naoExequivel:
        return 'naoExequivel';
    }
  }
}

ProjectStatus projectStatusFromKey(String key) {
  switch (key) {
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
  });

  factory Project.fromMap(Map<String, dynamic> map, String id) {
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
    };
  }
}
