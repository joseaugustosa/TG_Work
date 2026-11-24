import '../models/ide_project_report_snapshot.dart';
import '../models/project.dart';
import 'clock_project_totals.dart';
import 'ide_project_session_summary.dart';

/// Calcula os totais do relatório por projeto (mesma lógica da Agenda IDE).
/// Total = sessões IDE + relógio (timer/manual) do mesmo projeto.
IdeProjectReportSnapshot computeIdeProjectReportSnapshot({
  required String userId,
  required Project project,
  IdeProjectSessionSummary? ideSummary,
  int clockSeconds = 0,
  DateTime? execStartDate,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final firstIde = ideSummary?.earliestIdeSessionDate;
  final ideSecs = ideSummary?.totalDurationSeconds ?? 0;
  final clockSecs = clockSeconds < 0 ? 0 : clockSeconds;
  final total = computeProjectTimeTotal(
    ideSeconds: ideSecs,
    clockSeconds: clockSecs,
  );

  return IdeProjectReportSnapshot(
    projectId: project.id,
    userId: userId,
    projectName: project.name,
    projectStatusKey: projectStatusToKey(project.status),
    ideSeconds: ideSecs,
    clockSeconds: clockSecs,
    kanbanCalendarSeconds: 0,
    totalSeconds: total,
    ideSessionCount: ideSummary?.sessionCount ?? 0,
    ideDistinctDays: ideSummary?.distinctLocalDays ?? 0,
    kanbanPeriodStart: null,
    kanbanPeriodEnd: null,
    firstIdeSessionAt: firstIde,
    updatedAt: clock,
  );
}

String projectStatusToKey(ProjectStatus status) => status.key;
