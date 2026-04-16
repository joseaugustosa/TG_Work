import 'package:cloud_firestore/cloud_firestore.dart';

/// Registo no histórico (`status_changes`).
/// [kind] `status` = entradas antigas (só mudança de estado em chips);
/// `audit` = qualquer alteração com [summaryLine] legível.
class StatusChange {
  final String id;
  final String entityType; // 'project', 'theme', 'development'
  final String entityId;
  final String entityName;
  final String kind; // 'status' | 'audit'
  final String summaryLine;
  final String oldStatusKey;
  final String oldStatusLabel;
  final String newStatusKey;
  final String newStatusLabel;
  final String changedBy;
  final String changedByName;
  final DateTime changedAt;

  StatusChange({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    this.kind = 'status',
    this.summaryLine = '',
    required this.oldStatusKey,
    required this.oldStatusLabel,
    required this.newStatusKey,
    required this.newStatusLabel,
    required this.changedBy,
    required this.changedByName,
    required this.changedAt,
  });

  bool get isAuditEntry => kind == 'audit' && summaryLine.trim().isNotEmpty;

  factory StatusChange.fromMap(Map<String, dynamic> map, String id) {
    final summary = (map['summaryLine'] as String?)?.trim() ?? '';
    final k = map['kind'] as String?;
    final kind = k ??
        ((summary.isNotEmpty) ? 'audit' : 'status');
    return StatusChange(
      id: id,
      entityType: map['entityType'] ?? '',
      entityId: map['entityId'] ?? '',
      entityName: map['entityName'] ?? '',
      kind: kind,
      summaryLine: summary,
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
      'kind': kind,
      'summaryLine': summaryLine,
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
