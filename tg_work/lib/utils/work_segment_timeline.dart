import '../models/active_work_clock.dart';

DateTime workSegmentLocalDay(DateTime dt) =>
    DateTime(dt.year, dt.month, dt.day);

/// Agrupa segmentos por dia local do [WorkTimeSegment.endedAt], dias e itens
/// do mais recente para o mais antigo.
Map<DateTime, List<WorkTimeSegment>> groupWorkSegmentsByLocalDay(
  Iterable<WorkTimeSegment> segments,
) {
  final byDay = <DateTime, List<WorkTimeSegment>>{};
  for (final s in segments) {
    final day = workSegmentLocalDay(s.endedAt);
    (byDay[day] ??= []).add(s);
  }
  for (final list in byDay.values) {
    list.sort((a, b) => b.endedAt.compareTo(a.endedAt));
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return {for (final d in days) d: byDay[d]!};
}
