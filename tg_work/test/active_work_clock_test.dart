import 'package:flutter_test/flutter_test.dart';
import 'package:tg_work/models/active_work_clock.dart';
import 'package:tg_work/models/work_target_kind.dart';

void main() {
  group('ActiveWorkClock.fromMap', () {
    test('parses running project clock with task description', () {
      final clock = ActiveWorkClock.fromMap({
        'activeTargetKind': 'project',
        'activeTargetId': 'p1',
        'activeProjectId': 'p1',
        'segmentStartedAt': DateTime.utc(2026, 1, 1, 10, 0, 0),
        'paused': false,
        'taskDescription': 'Implementar login',
      });

      expect(clock, isNotNull);
      expect(clock!.kind, WorkTargetKind.project);
      expect(clock.targetId, 'p1');
      expect(clock.projectId, 'p1');
      expect(clock.paused, isFalse);
      expect(clock.taskDescription, 'Implementar login');
      expect(clock.isRunningOn(WorkTargetKind.project, 'p1'), isTrue);
      expect(clock.liveSegmentSeconds(DateTime.utc(2026, 1, 1, 10, 0, 30)), 30);
    });

    test('paused clock does not accumulate live seconds', () {
      final clock = ActiveWorkClock.fromMap({
        'activeTargetKind': 'theme',
        'activeTargetId': 't1',
        'activeProjectId': 'p1',
        'paused': true,
        'taskDescription': 'Reunião',
      });

      expect(clock, isNotNull);
      expect(clock!.paused, isTrue);
      expect(clock.kind, WorkTargetKind.theme);
      expect(clock.liveSegmentSeconds(DateTime.utc(2026, 1, 1, 12)), 0);
      expect(clock.isRunningOn(WorkTargetKind.theme, 't1'), isFalse);
      expect(clock.isActiveOn(WorkTargetKind.theme, 't1'), isTrue);
    });

    test('legacy activeProjectId without kind is project', () {
      final clock = ActiveWorkClock.fromMap({
        'activeProjectId': 'legacy-p',
        'segmentStartedAt': DateTime.utc(2026, 2, 1, 8),
      });

      expect(clock, isNotNull);
      expect(clock!.kind, WorkTargetKind.project);
      expect(clock.targetId, 'legacy-p');
      expect(clock.projectId, 'legacy-p');
    });

    test('returns null when no target', () {
      expect(ActiveWorkClock.fromMap({}), isNull);
      expect(ActiveWorkClock.fromMap({'paused': true}), isNull);
    });
  });

  group('WorkTargetKind', () {
    test('round-trips keys', () {
      expect(WorkTargetKind.project.key, 'project');
      expect(WorkTargetKind.theme.key, 'theme');
      expect(WorkTargetKind.development.key, 'development');
      expect(workTargetKindFromKey('theme'), WorkTargetKind.theme);
      expect(workTargetKindFromKey('development'), WorkTargetKind.development);
      expect(workTargetKindFromKey('nope'), WorkTargetKind.project);
    });

    test('totals doc id', () {
      expect(
        workTotalsDocId('u1', WorkTargetKind.theme, 't9'),
        'u1__theme__t9',
      );
      expect(
        workTotalsDocId('u1', WorkTargetKind.project, 'p9'),
        'u1__wk__p9',
      );
    });
  });
}
