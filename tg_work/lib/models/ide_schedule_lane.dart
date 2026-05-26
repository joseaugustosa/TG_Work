/// Colunas Kanban da agenda IDE (à parte das entidades Projetos / Temas).
enum IdeScheduleLane {
  backlog,
  inProgress,
  done,
}

IdeScheduleLane? ideLaneFromFirestore(String? v) {
  switch (v) {
    case 'backlog':
      return IdeScheduleLane.backlog;
    case 'progress':
      return IdeScheduleLane.inProgress;
    case 'done':
      return IdeScheduleLane.done;
    default:
      return null;
  }
}

IdeScheduleLane ideLaneOrBacklog(String? v) =>
    ideLaneFromFirestore(v) ?? IdeScheduleLane.backlog;

extension IdeScheduleLaneX on IdeScheduleLane {
  String get firebaseValue {
    switch (this) {
      case IdeScheduleLane.backlog:
        return 'backlog';
      case IdeScheduleLane.inProgress:
        return 'progress';
      case IdeScheduleLane.done:
        return 'done';
    }
  }

  String get uiLabelPt {
    switch (this) {
      case IdeScheduleLane.backlog:
        return 'À planear';
      case IdeScheduleLane.inProgress:
        return 'Em curso';
      case IdeScheduleLane.done:
        return 'Concluído';
    }
  }
}
