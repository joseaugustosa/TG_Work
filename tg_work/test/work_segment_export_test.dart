import 'package:flutter_test/flutter_test.dart';
import 'package:tg_work/models/work_target_kind.dart';
import 'package:tg_work/utils/work_segment_export.dart';

void main() {
  test('buildWorkSegmentExportFields inclui data, horas e evento', () {
    final started = DateTime(2026, 11, 24, 9, 15, 30);
    final ended = DateTime(2026, 11, 24, 11, 0, 0);
    final fields = buildWorkSegmentExportFields(
      userId: 'u1',
      kind: WorkTargetKind.project,
      targetId: 'p1',
      projectId: 'p1',
      description: 'Reunião',
      startedAt: started,
      endedAt: ended,
      durationSeconds: 6300,
      source: WorkSegmentSource.timer,
      event: WorkSegmentEvent.stop,
    );

    expect(fields['userId'], 'u1');
    expect(fields['targetKind'], 'project');
    expect(fields['targetId'], 'p1');
    expect(fields['projectId'], 'p1');
    expect(fields['description'], 'Reunião');
    expect(fields['durationSeconds'], 6300);
    expect(fields['workDay'], '2026-11-24');
    expect(fields['startedAtIso'], started.toIso8601String());
    expect(fields['endedAtIso'], ended.toIso8601String());
    expect(fields['source'], 'timer');
    expect(fields['event'], 'stop');
    expect(fields['startedAt'], started);
    expect(fields['endedAt'], ended);
  });
}
