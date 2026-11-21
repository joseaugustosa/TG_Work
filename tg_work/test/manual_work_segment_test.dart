import 'package:flutter_test/flutter_test.dart';
import 'package:tg_work/utils/manual_work_segment.dart';

void main() {
  test('manualWorkSegmentWindow ends at 18h and backs duration', () {
    final w = manualWorkSegmentWindow(
      DateTime(2026, 5, 10, 3, 0),
      90 * 60,
    );
    expect(w.endedAt, DateTime(2026, 5, 10, 18));
    expect(w.startedAt, DateTime(2026, 5, 10, 16, 30));
  });

  test('rejects non-positive duration', () {
    expect(() => manualWorkSegmentWindow(DateTime(2026, 1, 1), 0), throwsArgumentError);
  });
}
