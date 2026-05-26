import 'package:cloud_firestore/cloud_firestore.dart';

/// Totais do «Relatório por projeto» (Agenda IDE), gravados em Firestore para
/// outras apps (ex.: cálculo de custos).
///
/// Documento: `user_ide_project_reports/{userId}/by_project/{projectId}`
/// O [projectId] é o ID estável dos dados de relatório por projeto.
class IdeProjectReportSnapshot {
  final String projectId;
  final String userId;
  final String projectName;
  final String projectStatusKey;
  final int ideSeconds;
  final int kanbanCalendarSeconds;
  final int totalSeconds;
  final int ideSessionCount;
  final int ideDistinctDays;
  final DateTime? kanbanPeriodStart;
  final DateTime? kanbanPeriodEnd;
  final DateTime? firstIdeSessionAt;
  final DateTime updatedAt;

  const IdeProjectReportSnapshot({
    required this.projectId,
    required this.userId,
    required this.projectName,
    required this.projectStatusKey,
    required this.ideSeconds,
    required this.kanbanCalendarSeconds,
    required this.totalSeconds,
    required this.ideSessionCount,
    required this.ideDistinctDays,
    this.kanbanPeriodStart,
    this.kanbanPeriodEnd,
    this.firstIdeSessionAt,
    required this.updatedAt,
  });

  static IdeProjectReportSnapshot? fromFirestore(String docId, Map<String, dynamic> m) {
    final uid = (m['userId'] as String?)?.trim() ?? '';
    final pid = (m['projectId'] as String?)?.trim() ?? docId.trim();
    if (uid.isEmpty || pid.isEmpty) return null;

    DateTime? ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    int i(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    return IdeProjectReportSnapshot(
      projectId: pid,
      userId: uid,
      projectName: (m['projectName'] as String?) ?? '',
      projectStatusKey: (m['projectStatusKey'] as String?) ?? '',
      ideSeconds: i(m['ideSeconds']),
      kanbanCalendarSeconds: i(m['kanbanCalendarSeconds']),
      totalSeconds: i(m['totalSeconds']),
      ideSessionCount: i(m['ideSessionCount']),
      ideDistinctDays: i(m['ideDistinctDays']),
      kanbanPeriodStart: ts(m['kanbanPeriodStart']),
      kanbanPeriodEnd: ts(m['kanbanPeriodEnd']),
      firstIdeSessionAt: ts(m['firstIdeSessionAt']),
      updatedAt: ts(m['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'projectId': projectId,
      'projectName': projectName,
      'projectStatusKey': projectStatusKey,
      'ideSeconds': ideSeconds,
      'kanbanCalendarSeconds': kanbanCalendarSeconds,
      'totalSeconds': totalSeconds,
      'ideSessionCount': ideSessionCount,
      'ideDistinctDays': ideDistinctDays,
      if (kanbanPeriodStart != null) 'kanbanPeriodStart': kanbanPeriodStart,
      if (kanbanPeriodEnd != null) 'kanbanPeriodEnd': kanbanPeriodEnd,
      if (firstIdeSessionAt != null) 'firstIdeSessionAt': firstIdeSessionAt,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
