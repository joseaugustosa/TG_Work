import 'package:cloud_firestore/cloud_firestore.dart';

import 'ide_schedule_lane.dart';

class IdeScheduleCard {
  final String id;
  final String title;
  final String notes;
  final IdeScheduleLane lane;

  /// `yyyy-MM-dd` opcional: dia de foco planeada.
  final String workDateIso;
  final String tgProjectId;

  /// Chave de agrupamento estável usada para reconciliação com sessões IDE:
  ///   - `tg:{tgProjectId}` quando há projeto ligado
  ///   - `ws:{workspaceName}` quando não há projeto ligado
  /// Fica vazio em cartões criados manualmente (sem sessões IDE).
  final String aggregateKey;

  /// Segundos IDE totais derivados das sessões sincronizadas (mesmo critério do relatório).
  final int ideTrackedSeconds;

  final double sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  IdeScheduleCard({
    required this.id,
    required this.title,
    required this.notes,
    required this.lane,
    required this.workDateIso,
    required this.tgProjectId,
    this.aggregateKey = '',
    this.ideTrackedSeconds = 0,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  static IdeScheduleCard fromFirestore(String docId, Map<String, dynamic> m) {
    DateTime readTs(dynamic v, DateTime fallback) {
      if (v is Timestamp) return v.toDate();
      return fallback;
    }

    final now = DateTime.now();

    double readOrder(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return 0;
    }

    int readIdeSecs(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    final tgPid = (m['tgProjectId'] as String?) ?? '';
    final aggKey = (m['aggregateKey'] as String?) ?? '';
    return IdeScheduleCard(
      id: docId,
      title: (m['title'] as String?)?.trim().isEmpty == false
          ? (m['title'] as String).trim()
          : '(sem título)',
      notes: (m['notes'] as String?) ?? '',
      lane: ideLaneOrBacklog(m['lane'] as String?),
      workDateIso: (m['workDateIso'] as String?) ?? '',
      tgProjectId: tgPid,
      aggregateKey: aggKey.isNotEmpty ? aggKey : (tgPid.isNotEmpty ? 'tg:$tgPid' : ''),
      ideTrackedSeconds: readIdeSecs(m['ideTrackedSeconds']),
      sortOrder: readOrder(m['sortOrder']),
      createdAt: readTs(m['createdAt'], now),
      updatedAt: readTs(m['updatedAt'], now),
    );
  }

  Map<String, dynamic> toCreateMap(double order) => {
        'title': title,
        if (notes.isNotEmpty) 'notes': notes,
        'lane': lane.firebaseValue,
        if (workDateIso.isNotEmpty) 'workDateIso': workDateIso,
        if (tgProjectId.isNotEmpty) 'tgProjectId': tgProjectId,
        if (aggregateKey.isNotEmpty) 'aggregateKey': aggregateKey,
        'ideTrackedSeconds': ideTrackedSeconds,
        'sortOrder': order,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  IdeScheduleCard copyWithLane(IdeScheduleLane lane) =>
      IdeScheduleCard(
        id: id,
        title: title,
        notes: notes,
        lane: lane,
        workDateIso: workDateIso,
        tgProjectId: tgProjectId,
        aggregateKey: aggregateKey,
        ideTrackedSeconds: ideTrackedSeconds,
        sortOrder: sortOrder,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
