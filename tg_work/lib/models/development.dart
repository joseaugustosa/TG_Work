import 'package:cloud_firestore/cloud_firestore.dart';

enum DevelopmentStatus { emAndamento, parado, bom, podeMelhorar, feito }

extension DevelopmentStatusExtension on DevelopmentStatus {
  String get label {
    switch (this) {
      case DevelopmentStatus.emAndamento:
        return 'Em Andamento';
      case DevelopmentStatus.parado:
        return 'Parado';
      case DevelopmentStatus.bom:
        return 'Bom';
      case DevelopmentStatus.podeMelhorar:
        return 'Pode Melhorar';
      case DevelopmentStatus.feito:
        return 'Feito';
    }
  }

  String get key {
    switch (this) {
      case DevelopmentStatus.emAndamento:
        return 'emAndamento';
      case DevelopmentStatus.parado:
        return 'parado';
      case DevelopmentStatus.bom:
        return 'bom';
      case DevelopmentStatus.podeMelhorar:
        return 'podeMelhorar';
      case DevelopmentStatus.feito:
        return 'feito';
    }
  }
}

DevelopmentStatus devStatusFromKey(String key) {
  switch (key) {
    case 'parado':
      return DevelopmentStatus.parado;
    case 'bom':
      return DevelopmentStatus.bom;
    case 'podeMelhorar':
      return DevelopmentStatus.podeMelhorar;
    case 'feito':
      return DevelopmentStatus.feito;
    default:
      return DevelopmentStatus.emAndamento;
  }
}

class Development {
  final String id;
  final String name;
  final String description;
  final DevelopmentStatus status;
  final String themeId;
  final String projectId;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final String? updatedBy;
  final String? updatedByName;
  final DateTime? updatedAt;

  Development({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.themeId,
    required this.projectId,
    this.createdBy = '',
    this.createdByName = '',
    required this.createdAt,
    this.updatedBy,
    this.updatedByName,
    this.updatedAt,
  });

  factory Development.fromMap(Map<String, dynamic> map, String id) {
    return Development(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      status: devStatusFromKey(map['status'] ?? ''),
      themeId: map['themeId'] ?? '',
      projectId: map['projectId'] ?? '',
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
      'status': status.key,
      'themeId': themeId,
      'projectId': projectId,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt,
      if (updatedBy != null) 'updatedBy': updatedBy,
      if (updatedByName != null) 'updatedByName': updatedByName,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }
}
