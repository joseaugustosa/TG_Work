import '../models/ide_project_report_snapshot.dart';
import '../models/project.dart';
import 'ide_project_session_summary.dart';
import 'kanban_ide_work_seconds.dart';

/// Calcula os totais do relatório por projeto (mesma lógica da Agenda IDE).
IdeProjectReportSnapshot computeIdeProjectReportSnapshot({
  required String userId,
  required Project project,
  IdeProjectSessionSummary? ideSummary,
  DateTime? execStartDate,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final isExequivel = project.status == ProjectStatus.exequivel;
  final firstIde = ideSummary?.earliestIdeSessionDate;
  final ideSecs = ideSummary?.totalDurationSeconds ?? 0;

  final kanbanPeriod = kanbanIdeReportPeriod(
    projectCreatedAt: project.createdAt,
    execStartDate: execStartDate,
    firstIdeSessionAt: firstIde,
    isExequivel: isExequivel,
    now: clock,
  );
  final kanbanStart = kanbanPeriod.start;
  final kanbanEnd = kanbanPeriod.end;
  final kanbanCalSecs = kanbanWorkSecondsForIdeReport(
    projectCreatedAt: project.createdAt,
    execStartDate: execStartDate,
    firstIdeSessionAt: firstIde,
    isExequivel: isExequivel,
    now: clock,
  );

  return IdeProjectReportSnapshot(
    projectId: project.id,
    userId: userId,
    projectName: project.name,
    projectStatusKey: projectStatusToKey(project.status),
    ideSeconds: ideSecs,
    kanbanCalendarSeconds: kanbanCalSecs,
    totalSeconds: ideSecs + kanbanCalSecs,
    ideSessionCount: ideSummary?.sessionCount ?? 0,
    ideDistinctDays: ideSummary?.distinctLocalDays ?? 0,
    kanbanPeriodStart: kanbanStart,
    kanbanPeriodEnd: kanbanEnd,
    firstIdeSessionAt: firstIde,
    updatedAt: clock,
  );
}

String projectStatusToKey(ProjectStatus status) {
  switch (status) {
    case ProjectStatus.exequivel:
      return 'exequivel';
    case ProjectStatus.emExecucao:
      return 'emExecucao';
    case ProjectStatus.concluido:
      return 'concluido';
    case ProjectStatus.naoExequivel:
      return 'naoExequivel';
  }
}
