import '../models/ide_project_report_snapshot.dart';
import '../models/project.dart';
import 'ide_project_session_summary.dart';

/// Calcula os totais do relatório por projeto (mesma lógica da Agenda IDE).
/// A contabilização é só tempo IDE (sessões); o Kanban não entra nos totais.
IdeProjectReportSnapshot computeIdeProjectReportSnapshot({
  required String userId,
  required Project project,
  IdeProjectSessionSummary? ideSummary,
  DateTime? execStartDate,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final firstIde = ideSummary?.earliestIdeSessionDate;
  final ideSecs = ideSummary?.totalDurationSeconds ?? 0;

  return IdeProjectReportSnapshot(
    projectId: project.id,
    userId: userId,
    projectName: project.name,
    projectStatusKey: projectStatusToKey(project.status),
    ideSeconds: ideSecs,
    kanbanCalendarSeconds: 0,
    totalSeconds: ideSecs,
    ideSessionCount: ideSummary?.sessionCount ?? 0,
    ideDistinctDays: ideSummary?.distinctLocalDays ?? 0,
    kanbanPeriodStart: null,
    kanbanPeriodEnd: null,
    firstIdeSessionAt: firstIde,
    updatedAt: clock,
  );
}

String projectStatusToKey(ProjectStatus status) => status.key;
