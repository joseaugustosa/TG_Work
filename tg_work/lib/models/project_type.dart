import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipo de projeto criado pelo utilizador (`project_types/{id}`).
class ProjectType {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;

  const ProjectType({
    required this.id,
    required this.name,
    this.createdBy = '',
    required this.createdAt,
  });

  factory ProjectType.fromMap(Map<String, dynamic> map, String id) {
    return ProjectType(
      id: id,
      name: (map['name'] as String?)?.trim() ?? '',
      createdBy: (map['createdBy'] as String?) ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'name': name.trim(),
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

/// Subtipo ligado a um tipo (`project_subtypes/{id}`).
class ProjectSubtype {
  final String id;
  final String typeId;
  final String name;
  final String createdBy;
  final DateTime createdAt;

  const ProjectSubtype({
    required this.id,
    required this.typeId,
    required this.name,
    this.createdBy = '',
    required this.createdAt,
  });

  factory ProjectSubtype.fromMap(Map<String, dynamic> map, String id) {
    return ProjectSubtype(
      id: id,
      typeId: (map['typeId'] as String?)?.trim() ?? '',
      name: (map['name'] as String?)?.trim() ?? '',
      createdBy: (map['createdBy'] as String?) ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'typeId': typeId.trim(),
        'name': name.trim(),
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
