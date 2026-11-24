import 'package:flutter_test/flutter_test.dart';
import 'package:tg_work/utils/clock_project_totals.dart';

void main() {
  test('mergeClockSecondsByProject soma project + theme + development', () {
    final merged = mergeClockSecondsByProject(
      projectDirect: {'p1': 100, 'p2': 50},
      themeByProject: {'p1': 40},
      developmentByProject: {'p1': 10, 'p3': 5},
    );
    expect(merged['p1'], 150);
    expect(merged['p2'], 50);
    expect(merged['p3'], 5);
  });

  test('computeProjectTimeTotal soma IDE + relógio', () {
    expect(computeProjectTimeTotal(ideSeconds: 100, clockSeconds: 25), 125);
    expect(computeProjectTimeTotal(ideSeconds: 0, clockSeconds: 0), 0);
  });
}
