import 'work_target_kind.dart';

/// Sessão de trabalho em curso para um utilizador (ver `user_work_clock/{uid}`).
class ActiveWorkClock {
  final WorkTargetKind kind;
  final String targetId;
  /// Projeto pai (igual a [targetId] quando [kind] é projeto).
  final String projectId;
  final DateTime? segmentStartedAt;
  final bool paused;
  final String taskDescription;

  const ActiveWorkClock({
    required this.kind,
    required this.targetId,
    required this.projectId,
    this.segmentStartedAt,
    this.paused = false,
    this.taskDescription = '',
  });

  bool isActiveOn(WorkTargetKind k, String id) =>
      kind == k && targetId == id;

  bool isRunningOn(WorkTargetKind k, String id) =>
      isActiveOn(k, id) && !paused && segmentStartedAt != null;

  int liveSegmentSeconds(DateTime now) {
    if (paused || segmentStartedAt == null) return 0;
    return now.difference(segmentStartedAt!).inSeconds.clamp(0, 8640000);
  }

  /// Aceita Timestamps Firestore ou [DateTime] (testes).
  static ActiveWorkClock? fromMap(Map<String, dynamic> d) {
    final kind = workTargetKindFromKey(d['activeTargetKind'] as String?);
    var targetId = (d['activeTargetId'] as String?)?.trim() ?? '';
    var projectId = (d['activeProjectId'] as String?)?.trim() ?? '';

    // Legacy: só activeProjectId.
    if (targetId.isEmpty && projectId.isNotEmpty) {
      targetId = projectId;
    }
    if (projectId.isEmpty &&
        targetId.isNotEmpty &&
        kind == WorkTargetKind.project) {
      projectId = targetId;
    }
    if (targetId.isEmpty) return null;

    final paused = d['paused'] == true;
    final desc = (d['taskDescription'] as String?)?.trim() ?? '';
    final started = _parseDate(d['segmentStartedAt']);

    return ActiveWorkClock(
      kind: kind,
      targetId: targetId,
      projectId: projectId.isNotEmpty ? projectId : targetId,
      segmentStartedAt: started,
      paused: paused,
      taskDescription: desc,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      final dyn = v as dynamic;
      final d = dyn.toDate();
      if (d is DateTime) return d;
    } catch (_) {}
    return null;
  }
}

/// Segmento gravado com descrição da tarefa.
class WorkTimeSegment {
  final String id;
  final String userId;
  final WorkTargetKind kind;
  final String targetId;
  final String projectId;
  final String description;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;

  const WorkTimeSegment({
    required this.id,
    required this.userId,
    required this.kind,
    required this.targetId,
    required this.projectId,
    required this.description,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
  });

  factory WorkTimeSegment.fromMap(Map<String, dynamic> map, String id) {
    DateTime parse(dynamic v) {
      if (v is DateTime) return v;
      try {
        return (v as dynamic).toDate() as DateTime;
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }

    final secs = map['durationSeconds'];
    return WorkTimeSegment(
      id: id,
      userId: (map['userId'] as String?) ?? '',
      kind: workTargetKindFromKey(map['targetKind'] as String?),
      targetId: (map['targetId'] as String?)?.trim() ?? '',
      projectId: (map['projectId'] as String?)?.trim() ?? '',
      description: (map['description'] as String?)?.trim() ?? '',
      startedAt: parse(map['startedAt']),
      endedAt: parse(map['endedAt']),
      durationSeconds: secs is int ? secs : (secs is num ? secs.toInt() : 0),
    );
  }
}
