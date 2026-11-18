/// Alvo do relógio de trabalho manual.
enum WorkTargetKind { project, theme, development }

extension WorkTargetKindX on WorkTargetKind {
  String get key {
    switch (this) {
      case WorkTargetKind.project:
        return 'project';
      case WorkTargetKind.theme:
        return 'theme';
      case WorkTargetKind.development:
        return 'development';
    }
  }

  String get label {
    switch (this) {
      case WorkTargetKind.project:
        return 'projeto';
      case WorkTargetKind.theme:
        return 'tema';
      case WorkTargetKind.development:
        return 'desenvolvimento';
    }
  }
}

WorkTargetKind workTargetKindFromKey(String? key) {
  switch ((key ?? '').trim()) {
    case 'theme':
      return WorkTargetKind.theme;
    case 'development':
      return WorkTargetKind.development;
    default:
      return WorkTargetKind.project;
  }
}

/// ID do documento de totais. Projetos mantêm o formato legacy `__wk__`.
String workTotalsDocId(String userId, WorkTargetKind kind, String targetId) {
  if (kind == WorkTargetKind.project) {
    return '${userId}__wk__$targetId';
  }
  return '${userId}__${kind.key}__$targetId';
}

/// Coleção Firestore para totais por tipo de alvo.
String workTotalsCollection(WorkTargetKind kind) {
  switch (kind) {
    case WorkTargetKind.project:
      return 'user_project_work';
    case WorkTargetKind.theme:
      return 'user_theme_work';
    case WorkTargetKind.development:
      return 'user_development_work';
  }
}
