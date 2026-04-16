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

  /// Registos novos (`kind == audit`) com texto; legacy só tinha setas de estado.
  bool get isAuditEntry => kind == 'audit' && summaryLine.trim().isNotEmpty;

  /// Texto a mostrar: campo gravado, ou síntese a partir do estado (docs antigos sem `summaryLine`).
  String get displaySummary {
    if (summaryLine.trim().isNotEmpty) return summaryLine.trim();
    if (oldStatusLabel.isNotEmpty || newStatusLabel.isNotEmpty) {
      return 'Alteração: estado ($oldStatusLabel → $newStatusLabel)';
    }
    return 'Alteração registada';
  }

  factory StatusChange.fromMap(Map<String, dynamic> map, String id) {
    String s(dynamic v) {
      if (v == null) return '';
      if (v is String) return v;
      return v.toString();
    }

    DateTime parseTime(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    final summary = s(map['summaryLine']).trim();
    final k = map['kind'] as String?;
    final kind = k ?? ((summary.isNotEmpty) ? 'audit' : 'status');
    return StatusChange(
      id: id,
      entityType: s(map['entityType']),
      entityId: s(map['entityId']),
      entityName: s(map['entityName']),
      kind: kind,
      summaryLine: summary,
      oldStatusKey: s(map['oldStatusKey']),
      oldStatusLabel: s(map['oldStatusLabel']),
      newStatusKey: s(map['newStatusKey']),
      newStatusLabel: s(map['newStatusLabel']),
      changedBy: s(map['changedBy']),
      changedByName: s(map['changedByName']),
      changedAt: parseTime(map['changedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    // Firestore: entradas `audit` devem ter sempre `summaryLine` visível no consola.
    final sl = summaryLine.trim();
    final summaryForStore = kind == 'audit'
        ? (sl.isEmpty ? 'Alteração registada' : sl)
        : sl;

    return {
      'entityType': entityType,
      'entityId': entityId,
      'entityName': entityName,
      'kind': kind,
      'summaryLine': summaryForStore,
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
