/// Agrega segundos do relógio (projeto directo + temas + desenvolvimentos)
/// no mapa {projectId -> totalSeconds}.
Map<String, int> mergeClockSecondsByProject({
  required Map<String, int> projectDirect,
  required Map<String, int> themeByProject,
  required Map<String, int> developmentByProject,
}) {
  final out = <String, int>{};
  void addAll(Map<String, int> src) {
    for (final e in src.entries) {
      if (e.key.isEmpty || e.value == 0) continue;
      out[e.key] = (out[e.key] ?? 0) + e.value;
    }
  }

  addAll(projectDirect);
  addAll(themeByProject);
  addAll(developmentByProject);
  return out;
}

/// Total do projeto = sessões IDE + relógio (manual/timer).
int computeProjectTimeTotal({
  required int ideSeconds,
  required int clockSeconds,
}) {
  final ide = ideSeconds < 0 ? 0 : ideSeconds;
  final clock = clockSeconds < 0 ? 0 : clockSeconds;
  return ide + clock;
}
