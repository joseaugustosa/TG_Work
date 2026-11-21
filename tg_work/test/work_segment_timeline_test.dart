import 'package:flutter_test/flutter_test.dart';
import 'package:tg_work/models/active_work_clock.dart';
import 'package:tg_work/models/work_target_kind.dart';
import 'package:tg_work/utils/work_segment_timeline.dart';

WorkTimeSegment _seg({
  required String id,
  required DateTime endedAt,
  int seconds = 60,
  String description = 'tarefa',
}) {
  return WorkTimeSegment(
    id: id,
    userId: 'u1',
    kind: WorkTargetKind.project,
    targetId: 'p1',
    projectId: 'p1',
    description: description,
    startedAt: endedAt.subtract(Duration(seconds: seconds)),
    endedAt: endedAt,
    durationSeconds: seconds,
    isManual: false,
  );
}

void main() {
  test('groupWorkSegmentsByLocalDay ordena dias e segmentos desc', () {
    final a = _seg(id: 'a', endedAt: DateTime(2026, 3, 10, 9));
    final b = _seg(id: 'b', endedAt: DateTime(2026, 3, 10, 18));
    final c = _seg(id: 'c', endedAt: DateTime(2026, 3, 11, 12));

    final grouped = groupWorkSegmentsByLocalDay([a, b, c]);

    expect(grouped.keys.toList(), [
      DateTime(2026, 3, 11),
      DateTime(2026, 3, 10),
    ]);
    expect(grouped[DateTime(2026, 3, 10)]!.map((s) => s.id).toList(), [
      'b',
      'a',
    ]);
    expect(grouped[DateTime(2026, 3, 11)]!.single.id, 'c');
  });
}
