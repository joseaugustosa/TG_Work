import 'package:cloud_firestore/cloud_firestore.dart';

class StatusChange {
  final String id;
  final String entityType; // 'project', 'theme', 'development'
  final String entityId;
  final String entityName;
  final String oldStatusKey;
  final String oldStatusLabel;
  final String newStatusKey;
  final String newStatusLabel;
  final String changedBy; // uid
  final String changedByName; // display name or email
  final DateTime changedAt;

  StatusChange({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.oldStatusKey,
    required this.oldStatusLabel,
    required this.newStatusKey,
    required this.newStatusLabel,
    required this.changedBy,
    required this.changedByName,
    required this.changedAt,
  });

  factory StatusChange.fromMap(Map<String, dynamic> map, String id) {
    return StatusChange(
      id: id,
      entityType: map['entityType'] ?? '',
      entityId: map['entityId'] ?? '',
      entityName: map['entityName'] ?? '',
      oldStatusKey: map['oldStatusKey'] ?? '',
      oldStatusLabel: map['oldStatusLabel'] ?? '',
      newStatusKey: map['newStatusKey'] ?? '',
      newStatusLabel: map['newStatusLabel'] ?? '',
      changedBy: map['changedBy'] ?? '',
      changedByName: map['changedByName'] ?? '',
      changedAt: (map['changedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'entityType': entityType,
      'entityId': entityId,
      'entityName': entityName,
      'oldStatusKey': oldStatusKey,
      'oldStatusLabel': oldStatusLabel,
      'newStatusKey': newStatusKey,
      'newStatusLabel': newStatusLabel,
      'changedBy': changedBy,
      'changedByName': changedByName,
      'changedAt': changedAt,
    };
  }
}
