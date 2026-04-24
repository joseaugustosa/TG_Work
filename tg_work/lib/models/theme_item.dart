import 'package:cloud_firestore/cloud_firestore.dart';

enum ThemeStatus { emEstudo, emAndamento, emAvaliacao, feito }

extension ThemeStatusExtension on ThemeStatus {
  String get label {
    switch (this) {
      case ThemeStatus.emEstudo:
        return 'Em Estudo';
      case ThemeStatus.emAndamento:
        return 'Em Andamento';
      case ThemeStatus.emAvaliacao:
        return 'Em Avaliação';
      case ThemeStatus.feito:
        return 'Feito';
    }
  }

  String get key {
    switch (this) {
      case ThemeStatus.emEstudo:
        return 'emEstudo';
      case ThemeStatus.emAndamento:
        return 'emAndamento';
      case ThemeStatus.emAvaliacao:
        return 'emAvaliacao';
      case ThemeStatus.feito:
        return 'feito';
    }
  }
}

ThemeStatus themeStatusFromKey(String key) {
  switch (key) {
    case 'emAndamento':
      return ThemeStatus.emAndamento;
    case 'emAvaliacao':
      return ThemeStatus.emAvaliacao;
    case 'feito':
      return ThemeStatus.feito;
    default:
      return ThemeStatus.emEstudo;
  }
}

class ThemeItem {
  final String id;
  final String name;
  final String description;
  final String? descriptionRecordingUrl;
  final ThemeStatus status;
  final String projectId;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final String? updatedBy;
  final String? updatedByName;
  final DateTime? updatedAt;

  ThemeItem({
    required this.id,
    required this.name,
    required this.description,
    this.descriptionRecordingUrl,
    required this.status,
    required this.projectId,
    this.createdBy = '',
    this.createdByName = '',
    required this.createdAt,
    this.updatedBy,
    this.updatedByName,
    this.updatedAt,
  });

  factory ThemeItem.fromMap(Map<String, dynamic> map, String id) {
    return ThemeItem(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      descriptionRecordingUrl: map['descriptionRecordingUrl'] as String?,
      status: themeStatusFromKey(map['status'] ?? ''),
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
      if (descriptionRecordingUrl != null) 'descriptionRecordingUrl': descriptionRecordingUrl,
      'status': status.key,
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
