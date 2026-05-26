/// Sessão de trabalho em curso para um utilizador (ver `user_work_clock/{uid}`).
class ActiveWorkClock {
  final String projectId;
  final DateTime segmentStartedAt;

  const ActiveWorkClock({
    required this.projectId,
    required this.segmentStartedAt,
  });
}
