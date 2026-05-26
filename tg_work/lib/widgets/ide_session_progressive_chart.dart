import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/ide_session_log.dart';
import '../models/project.dart';
import '../utils/ide_session_time_rollup.dart';
import '../utils/kanban_ide_work_seconds.dart';
import '../utils/work_timer_format.dart';

/// Vista «progressiva»: anos → meses → dias, com uma barra horizontal por projeto.
/// Suporta barras bicolores: azul escuro = IDE, verde = Kanban (dias × 8 h, igual ao relatório).
class IdeSessionProgressiveChart extends StatefulWidget {
  final List<IdeSessionLog> logs;
  final List<Project> projects;

  /// Mapa projectId → data de início de "Em Execução" (de status_changes).
  final Map<String, DateTime> execDates;

  const IdeSessionProgressiveChart({
    super.key,
    required this.logs,
    required this.projects,
    this.execDates = const {},
  });

  @override
  State<IdeSessionProgressiveChart> createState() => _IdeSessionProgressiveChartState();
}

enum _Drill { years, months, days }

class _IdeSessionProgressiveChartState extends State<IdeSessionProgressiveChart> {
  _Drill _drill = _Drill.years;
  int? _year;
  int? _month;

  static const _mesesPt = <String>[
    '', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
  ];

  // Primeira sessão IDE por projectId (calculado uma vez, cache lazy)
  Map<String, DateTime>? _firstIdeCache;
  Map<String, DateTime> get _firstIdeByProjectId {
    if (_firstIdeCache != null) return _firstIdeCache!;
    final map = <String, DateTime>{};
    for (final log in widget.logs) {
      if (log.tgProjectId.isEmpty) continue;
      final cur = map[log.tgProjectId];
      if (cur == null || log.openedAt.isBefore(cur)) {
        map[log.tgProjectId] = log.openedAt;
      }
    }
    return _firstIdeCache = map;
  }

  @override
  void didUpdateWidget(covariant IdeSessionProgressiveChart old) {
    super.didUpdateWidget(old);
    if (old.logs != widget.logs) _firstIdeCache = null;
  }

  /// Totais IDE + Kanban iguais ao «Relatório por projeto».
  (int ideSecs, int kanbanSecs) _reportTotalsForKey(String key) {
    if (key.startsWith('tg:')) {
      final pid = key.substring(3);
      final project = widget.projects.where((p) => p.id == pid).firstOrNull;
      if (project == null) return (0, 0);

      final ideSecs = widget.logs
          .where((l) => l.tgProjectId.trim() == pid)
          .fold<int>(0, (s, l) => s + l.durationSeconds);

      final kanbanSecs = kanbanWorkSecondsForIdeReport(
        projectCreatedAt: project.createdAt,
        execStartDate: widget.execDates[pid],
        firstIdeSessionAt: _firstIdeByProjectId[pid],
        isExequivel: project.status == ProjectStatus.exequivel,
      );
      return (ideSecs, kanbanSecs);
    }

    if (key.startsWith('ws:')) {
      final ws = key.substring(3);
      final ideSecs = widget.logs
          .where((l) =>
              l.tgProjectId.trim().isEmpty &&
              l.workspaceName.trim() == ws)
          .fold<int>(0, (s, l) => s + l.durationSeconds);
      return (ideSecs, 0);
    }

    return (0, 0);
  }

  String _projectLabel(String key) {
    if (key.startsWith('tg:')) {
      final pid = key.substring(3);
      for (final p in widget.projects) {
        if (p.id == pid) return p.name;
      }
      return 'Projeto $pid';
    }
    if (key.startsWith('ws:')) {
      final ws = key.substring(3);
      return ws.isNotEmpty ? ws : 'Sem workspace';
    }
    if (key.isEmpty) return 'Sem projeto ligado';
    for (final p in widget.projects) {
      if (p.id == key) return p.name;
    }
    return key;
  }

  void _goYears() => setState(() { _drill = _Drill.years; _year = null; _month = null; });
  void _goMonths(int y) => setState(() { _drill = _Drill.months; _year = y; _month = null; });
  void _goDays(int y, int m) => setState(() { _drill = _Drill.days; _year = y; _month = m; });

  Widget _breadcrumb() {
    return Wrap(
      spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ActionChip(label: const Text('Anos'), onPressed: _goYears),
        if (_year != null) ...[
          const Icon(Icons.chevron_right, size: 18),
          ActionChip(label: Text('${_year!}'), onPressed: () => _goMonths(_year!)),
        ],
        if (_month != null) ...[
          const Icon(Icons.chevron_right, size: 18),
          Chip(label: Text(_mesesPt[_month!.clamp(1, 12)])),
        ],
      ],
    );
  }

  Widget _barsPerProject({
    bool showAllProjects = false,
  }) {
    // Ordena pela mesma ordem do relatório: projetos TG Work por createdAt desc,
    // workspaces sem projeto ligado no final.
    final sortedProjects = [...widget.projects]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Entradas de projetos TG Work — totais iguais ao relatório
    final tgEntries = <String>[];
    for (final p in sortedProjects) {
      final key = 'tg:${p.id}';
      final totals = _reportTotalsForKey(key);
      if (totals.$1 + totals.$2 > 0 || showAllProjects) {
        tgEntries.add(key);
      }
    }

    // Workspaces sem projeto ligado (ws:...) — no final
    final wsKeys = <String>{};
    for (final log in widget.logs) {
      if (log.tgProjectId.trim().isNotEmpty) continue;
      final key = 'ws:${log.workspaceName.trim()}';
      wsKeys.add(key);
    }
    final unlinkedKeys = wsKeys.toList()
      ..sort((a, b) => _projectLabel(a).compareTo(_projectLabel(b)));

    final allKeys = [...tgEntries, ...unlinkedKeys];
    if (allKeys.isEmpty) {
      return Text('Sem tempo registado',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600));
    }

    // Totais por chave (mesma lógica do relatório)
    final totalsByKey = <String, (int, int)>{
      for (final key in allKeys) key: _reportTotalsForKey(key),
    };
    final grandTotal = allKeys.fold<int>(
      0, (s, key) => s + totalsByKey[key]!.$1 + totalsByKey[key]!.$2);
    final effectiveTotal = math.max(1, grandTotal);

    const labelFlex = 5;
    const barFlex = 10;
    const valueFlex = 3;
    const ideColor = Color(0xFF1A237E);
    const kanbanColor = Color(0xFF00796B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final key in allKeys)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: labelFlex,
                  child: Text(
                    _projectLabel(key),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.2,
                      color: totalsByKey[key]!.$1 + totalsByKey[key]!.$2 > 0
                          ? Colors.grey.shade900
                          : Colors.grey.shade500,
                      fontWeight: totalsByKey[key]!.$1 + totalsByKey[key]!.$2 > 0
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                Expanded(
                  flex: barFlex,
                  child: () {
                    final ideSecs = totalsByKey[key]!.$1;
                    final kanbanSecs = totalsByKey[key]!.$2;
                    final entrySecs = ideSecs + kanbanSecs;
                    if (entrySecs == 0) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text('sem sessões',
                            style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.grey.shade400,
                                fontStyle: FontStyle.italic)),
                      );
                    }
                    final tooltipLines = [
                      _projectLabel(key),
                      if (ideSecs > 0) 'IDE: ${formatWorkDurationSeconds(ideSecs)}',
                      if (kanbanSecs > 0) 'Kanban: ${formatWorkDurationSeconds(kanbanSecs)}',
                      'Total: ${formatWorkDurationSeconds(entrySecs)}',
                      '${((100 * entrySecs) / effectiveTotal).toStringAsFixed(1)}% do total',
                    ].join('\n');
                    return Tooltip(
                      message: tooltipLines,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final totalWidth = math.max(
                              3.0, constraints.maxWidth * entrySecs / effectiveTotal);
                          final ideWidth = kanbanSecs > 0 && ideSecs > 0
                              ? totalWidth * ideSecs / entrySecs
                              : (ideSecs > 0 ? totalWidth : 0.0);
                          final kanbanWidth = totalWidth - ideWidth;
                          return SizedBox(
                            height: 18,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (ideWidth > 0)
                                      Container(
                                          width: ideWidth,
                                          height: 18,
                                          color: ideColor),
                                    if (kanbanWidth > 0)
                                      Container(
                                          width: kanbanWidth,
                                          height: 18,
                                          color: kanbanColor.withValues(alpha: 0.85)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }(),
                ),
                Expanded(
                  flex: valueFlex,
                  child: () {
                    final ideSecs = totalsByKey[key]!.$1;
                    final kanbanSecs = totalsByKey[key]!.$2;
                    final entrySecs = ideSecs + kanbanSecs;
                    if (entrySecs == 0) {
                      return Text('—',
                          textAlign: TextAlign.end,
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade400));
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatWorkDurationSeconds(entrySecs),
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A237E)),
                        ),
                        if (kanbanSecs > 0 && ideSecs > 0)
                          Text(
                            '${formatWorkDurationSeconds(ideSecs)} IDE · ${formatWorkDurationSeconds(kanbanSecs)} Kanban',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                                fontSize: 9.5,
                                color: Colors.grey.shade600),
                          ),
                      ],
                    );
                  }(),
                ),
              ],
            ),
          ),
        // Legenda (só quando há Kanban visível)
        if (totalsByKey.values.any((t) => t.$2 > 0))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(
                        color: ideColor,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                Text('IDE', style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                const SizedBox(width: 12),
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(
                        color: kanbanColor.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                Text('Kanban', style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _rowTile({
    required String title,
    required VoidCallback? onTap,
    bool showAllProjects = false,
  }) {
    var totalSecs = 0;
    for (final p in widget.projects) {
      final t = _reportTotalsForKey('tg:${p.id}');
      totalSecs += t.$1 + t.$2;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                  Text(
                    formatWorkDurationSeconds(totalSecs),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1A237E)),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios,
                        size: 14, color: Colors.grey.shade600),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              _barsPerProject(showAllProjects: showAllProjects),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final byDay = rollupIdeSessionsByClosedDay(widget.logs);
    if (byDay.isEmpty) return const SizedBox.shrink();

    final byMonth = rollupByMonthFromDays(byDay);
    final byYear = rollupByYearFromDays(byDay);

    late final Widget body;
    switch (_drill) {
      case _Drill.years:
        final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
        body = Column(
          children: [
            for (final y in years)
              _rowTile(
                title: 'Ano $y',
                onTap: () => _goMonths(y),
                showAllProjects: true,
              ),
          ],
        );
        break;
      case _Drill.months:
        final y = _year!;
        final months = byMonth.entries
            .where((e) => e.key.year == y)
            .map((e) => e.key.month)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
        body = Column(
          children: [
            for (final m in months)
              _rowTile(
                title: '${_mesesPt[m]} $y',
                onTap: () => _goDays(y, m),
                showAllProjects: true,
              ),
          ],
        );
        break;
      case _Drill.days:
        final y = _year!;
        final m = _month!;
        final days = byDay.entries
            .where((e) => e.key.year == y && e.key.month == m)
            .map((e) => e.key)
            .toList()
          ..sort((a, b) => b.compareTo(a));
        body = Column(
          children: [
            for (final d in days)
              _rowTile(
                title: '${d.day}/${d.month}/${d.year}',
                onTap: null,
                showAllProjects: true,
              ),
          ],
        );
        break;
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Tempo IDE por período',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Cada barra = total IDE + Kanban (igual ao relatório; Kanban = dias × 8 h). '
              'Azul = IDE · verde = Kanban, proporcional dentro da barra.',
              style: TextStyle(
                  fontSize: 11.5, height: 1.35, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            _breadcrumb(),
            const Divider(height: 20),
            body,
          ],
        ),
      ),
    );
  }
}
