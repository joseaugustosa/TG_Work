import '../models/work_target_kind.dart';

/// Origem do registo em `user_work_segments` (para outros softwares).
enum WorkSegmentSource { timer, manual }

extension WorkSegmentSourceX on WorkSegmentSource {
  String get key => switch (this) {
        WorkSegmentSource.timer => 'timer',
        WorkSegmentSource.manual => 'manual',
      };
}

/// Evento que fechou o segmento do relógio.
enum WorkSegmentEvent { pause, stop, checkpoint, switchTarget, manual }

extension WorkSegmentEventX on WorkSegmentEvent {
  String get key => switch (this) {
        WorkSegmentEvent.pause => 'pause',
        WorkSegmentEvent.stop => 'stop',
        WorkSegmentEvent.checkpoint => 'checkpoint',
        WorkSegmentEvent.switchTarget => 'switch',
        WorkSegmentEvent.manual => 'manual',
      };
}

String workSegmentWorkDay(DateTime endedAt) {
  final y = endedAt.year.toString().padLeft(4, '0');
  final m = endedAt.month.toString().padLeft(2, '0');
  final d = endedAt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Campos estáveis do documento `user_work_segments` para consumo externo.
///
/// `startedAt` / `endedAt` ficam como [DateTime]; o serviço converte para Timestamp.
Map<String, dynamic> buildWorkSegmentExportFields({
  required String userId,
  required WorkTargetKind kind,
  required String targetId,
  required String projectId,
  required String description,
  required DateTime startedAt,
  required DateTime endedAt,
  required int durationSeconds,
  required WorkSegmentSource source,
  required WorkSegmentEvent event,
}) {
  return {
    'userId': userId,
    'targetKind': kind.key,
    'targetId': targetId,
    'projectId': projectId,
    'description': description,
    'startedAt': startedAt,
    'endedAt': endedAt,
    'durationSeconds': durationSeconds,
    'workDay': workSegmentWorkDay(endedAt),
    'startedAtIso': startedAt.toIso8601String(),
    'endedAtIso': endedAt.toIso8601String(),
    'source': source.key,
    'event': event.key,
  };
}
