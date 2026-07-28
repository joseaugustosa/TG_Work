import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/ide_session_log.dart';
import '../models/project.dart';
import '../utils/ide_session_time_rollup.dart';
import '../utils/work_timer_format.dart';

/// Vista «progressiva»: anos → meses → dias, com uma barra horizontal por projeto.
/// Contabiliza apenas tempo IDE (sessões).
class IdeSessionProgressiveChart extends StatefulWidget {
  final List<IdeSessionLog> logs;
  final List<Project> projects;

  const IdeSessionProgressiveChart({
    super.key,
    required this.logs,
    required this.projects,
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

  /// Segundos IDE por chave `tg:{id}` ou `ws:{workspace}`.
  int _ideSecondsForKey(String key) {
    if (key.startsWith('tg:')) {
      final pid = key.substring(3);
      return widget.logs
          .where((l) => l.tgProjectId.trim() == pid)
          .fold<int>(0, (s, l) => s + l.durationSeconds);
    }
    if (key.startsWith('ws:')) {
      final ws = key.substring(3);
      return widget.logs
          .where((l) =>
              l.tgProjectId.trim().isEmpty &&
              l.workspaceName.trim() == ws)
          .fold<int>(0, (s, l) => s + l.durationSeconds);
    }
    return 0;
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
    final sortedProjects = [...widget.projects]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final tgEntries = <String>[];
    for (final p in sortedProjects) {
      final key = 'tg:${p.id}';
      final secs = _ideSecondsForKey(key);
      if (secs > 0 || showAllProjects) {
        tgEntries.add(key);
      }
    }

    final wsKeys = <String>{};
    for (final log in widget.logs) {
      if (log.tgProjectId.trim().isNotEmpty) continue;
      final key = 'ws:${log.workspaceName.trim()}';
      if (_ideSecondsForKey(key) > 0) wsKeys.add(key);
    }
    final wsEntries = wsKeys.toList()..sort();

    final allKeys = [...tgEntries, ...wsEntries];
    if (allKeys.isEmpty) {
      return Text(
        'Sem tempo IDE neste período.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      );
    }

    final secsByKey = <String, int>{
      for (final key in allKeys) key: _ideSecondsForKey(key),
    };
    final grandTotal = allKeys.fold<int>(0, (s, key) => s + secsByKey[key]!);
    final effectiveTotal = math.max(1, grandTotal);

    const labelFlex = 5;
    const barFlex = 10;
    const valueFlex = 3;
    const ideColor = Color(0xFF1A237E);

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
                      color: secsByKey[key]! > 0
                          ? Colors.grey.shade900
                          : Colors.grey.shade500,
                      fontWeight: secsByKey[key]! > 0
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                Expanded(
                  flex: barFlex,
                  child: () {
                    final ideSecs = secsByKey[key]!;
                    if (ideSecs == 0) {
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
                      'IDE: ${formatWorkDurationSeconds(ideSecs)}',
                      '${((100 * ideSecs) / effectiveTotal).toStringAsFixed(1)}% do total',
                    ].join('\n');
                    return Tooltip(
                      message: tooltipLines,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = math.max(
                              3.0, constraints.maxWidth * ideSecs / effectiveTotal);
                          return SizedBox(
                            height: 18,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  width: width,
                                  height: 18,
                                  color: ideColor,
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
                    final ideSecs = secsByKey[key]!;
                    if (ideSecs == 0) {
                      return Text('—',
                          textAlign: TextAlign.end,
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade400));
                    }
                    return Text(
                      formatWorkDurationSeconds(ideSecs),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A237E)),
                    );
                  }(),
                ),
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
      totalSecs += _ideSecondsForKey('tg:${p.id}');
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
              'Cada barra = tempo das sessões IDE neste período.',
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
