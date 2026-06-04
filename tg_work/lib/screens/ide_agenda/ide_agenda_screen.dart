import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/ide_schedule_card.dart';
import '../../models/ide_schedule_lane.dart';
import '../../models/ide_session_log.dart';
import '../../models/project.dart';
import '../../services/firestore_service.dart';
import '../../utils/firestore_messages.dart';
import '../../utils/ide_project_session_summary.dart';
import '../../utils/user_display.dart';
import '../../utils/kanban_ide_work_seconds.dart';
import '../../utils/work_timer_format.dart';
import '../../widgets/ide_session_progressive_chart.dart';
import '../../widgets/status_kanban_board.dart';

/// Agenda Kanban própria (sessões IDE) + histórico gravado pela extensão VS Code/Cursor.
class IdeAgendaScreen extends StatefulWidget {
  const IdeAgendaScreen({super.key});

  @override
  State<IdeAgendaScreen> createState() => _IdeAgendaScreenState();
}

class _IdeAgendaScreenState extends State<IdeAgendaScreen> {
  late final FirestoreService _service;

  StreamSubscription<User?>? _authSub;
  Timer? _kanbanSyncDebounce;
  StreamSubscription<List<Project>>? _projSub;
  StreamSubscription<IdeSessionLogsQuerySnapshot>? _logsSub;
  StreamSubscription<List<IdeScheduleCard>>? _cardsSub;
  StreamSubscription<Set<String>>? _excludedSub;
  StreamSubscription<Map<String, DateTime>>? _execDatesSub;
  String? _syncUid;

  Future<void>? _reconcileTail;

  List<Project> _projectsForSync = [];
  List<IdeSessionLog> _logsForSync = [];
  List<IdeSessionLog> _allLogsForSync = [];
  List<IdeScheduleCard> _cardsForSync = [];
  Set<String> _excludedKeysForSync = {};
  Map<String, DateTime> _firstExecDateForSync = {};
  bool _axiomRemovalDone = false;

  @override
  void initState() {
    super.initState();
    _service = FirestoreService();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      final uid = user?.uid;
      if (uid == null || uid.isEmpty) {
        _disposeKanbanSync();
      } else {
        _bindKanbanAutoSync(uid);
      }
    });
  }

  void _disposeKanbanSync() {
    _kanbanSyncDebounce?.cancel();
    _kanbanSyncDebounce = null;
    _projSub?.cancel();
    _logsSub?.cancel();
    _cardsSub?.cancel();
    _excludedSub?.cancel();
    _execDatesSub?.cancel();
    _projSub = null;
    _logsSub = null;
    _cardsSub = null;
    _excludedSub = null;
    _execDatesSub = null;
    _syncUid = null;
    _projectsForSync = [];
    _logsForSync = [];
    _allLogsForSync = [];
    _cardsForSync = [];
    _excludedKeysForSync = {};
    _firstExecDateForSync = {};
  }

  void _bindKanbanAutoSync(String uid) {
    if (_syncUid == uid && _projSub != null) return;

    _disposeKanbanSync();
    _syncUid = uid;

    void scheduleReconcile() {
      if (!_axiomRemovalDone && _projectsForSync.isNotEmpty) {
        _axiomRemovalDone = true;
        unawaited(
          _service
              .removeFromIdeAgendaByDisplayName(
                userId: uid,
                displayName: 'Axiom-3D-Wood',
                projects: _projectsForSync,
                cards: _cardsForSync,
              )
              .catchError((Object e) {
            debugPrint('TG_Work: remover Axiom-3D-Wood da agenda: $e');
          }),
        );
      }
      _kanbanSyncDebounce?.cancel();
      _kanbanSyncDebounce = Timer(const Duration(milliseconds: 450), () {
        _reconcileTail = (_reconcileTail ?? Future<void>.value()).then((_) async {
          try {
            await _service.reconcileIdeKanbanFromIdeSessions(
              userId: uid,
              userName: firebaseUserDisplayLabel(
                FirebaseAuth.instance.currentUser,
              ),
              logs: _logsForSync,
              allLogs: _allLogsForSync,
              projects: _projectsForSync,
              cards: _cardsForSync,
              excludedAggregateKeys: _excludedKeysForSync,
            );
            await _service.syncIdeProjectReports(
              userId: uid,
              projects: _projectsForSync,
              completedLogs: _logsForSync,
              firstExecDateByProjectId: _firstExecDateForSync,
              excludedAggregateKeys: _excludedKeysForSync,
            );
          } catch (e, st) {
            debugPrint('TG_Work: sincronizar Kanban IDE: $e\n$st');
          }
        });
      });
    }

    _projSub = _service.getProjects().listen((p) {
      _projectsForSync = p;
      scheduleReconcile();
    });
    _logsSub = _service.watchIdeSessionLogs(uid, limit: 2500).listen((page) {
      _logsForSync = page.completedSessions;
      _allLogsForSync = page.allParsedSessions;
      scheduleReconcile();
    });
    _cardsSub = _service.watchIdeScheduleCards(uid).listen((c) {
      _cardsForSync = c;
      scheduleReconcile();
    });
    _excludedSub = _service.watchIdeAgendaExcludedKeys(uid).listen((keys) {
      _excludedKeysForSync = keys;
      scheduleReconcile();
    });
    _execDatesSub = _service.watchProjectFirstExecutionDateMap().listen((map) {
      _firstExecDateForSync = map;
      scheduleReconcile();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _disposeKanbanSync();
    super.dispose();
  }

  Color _laneHeaderColor(IdeScheduleLane lane) {
    switch (lane) {
      case IdeScheduleLane.backlog:
        return const Color(0xFFB0BEC5);
      case IdeScheduleLane.inProgress:
        return const Color(0xFFFFB74D);
      case IdeScheduleLane.done:
        return const Color(0xFFA5D6A7);
    }
  }

  String _editorLabelPt(String editor) {
    switch (editor) {
      case 'cursor':
        return 'Cursor';
      case 'vscode':
      case 'vscode_insiders':
        return 'VS Code';
      default:
        return editor.isEmpty ? 'IDE' : editor;
    }
  }

  Widget _agendaBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '•  ',
            style: TextStyle(fontWeight: FontWeight.bold, height: 1.4),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.8, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionsSection(String uid, String? email, List<Project> projects, List<IdeScheduleCard> ideCards) {
    const logsLimit =
        2500; // evita ocupar página com stubs duration=0 dos últimos registos legíveis ainda suficientemente altos para o relatório
    return StreamBuilder<IdeSessionLogsQuerySnapshot>(
      stream: _service.watchIdeSessionLogs(uid, limit: logsLimit),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Erro ao carregar sessões IDE',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 10),
                SelectableText(firestoreIdeSessionsErrorHint(snap.error)),
              ],
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
          return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        }
        final page = snap.data ?? IdeSessionLogsQuerySnapshot.empty;
        if (page.allParsedSessions.isEmpty) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (page.hasUnreadableFirestoreDocs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'O Firestore devolveu ${page.queriedDocumentCount} documento(s) em `user_ide_session_logs`, '
                          'mas nenhum pode ser lido aqui (costuma ser `userId` em falta ou com tipo inesperado). '
                          'Confirma um documento manualmente na consola Firebase.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ),
                    ),
                  ),
                Card(
                  color: Colors.amber.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFF1A237E)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                page.queriedDocumentCount == 0
                                    ? 'Sem linhas na coleção user_ide_session_logs para este utilizador'
                                    : 'Sem linhas interpretáveis — vê o cartão vermelho acima ou a checklist abaixo',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFF1A237E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          'UID nesta app: $uid',
                          style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace'),
                        ),
                        if (email != null && email.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: SelectableText(
                              'Email nesta app: ${email.trim()}',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Projecto Firebase desta build: deve ser o mesmo em tgWorkIde.firebaseProjectId na extensão '
                          '(há exemplo em integrations/vscode-tg-work).',
                          style:
                              TextStyle(fontSize: 12, height: 1.35, color: Colors.grey.shade900),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Se o UID/email não coincidirem com o login da extensão, não aparece nada na agenda.',
                          style:
                              TextStyle(fontSize: 12, height: 1.35, color: Colors.grey.shade900),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'A extensão pode estar a gravar só no PC. Para aparecer na nuvem:',
                          style: TextStyle(fontSize: 13, height: 1.35, color: Colors.grey.shade900),
                        ),
                        const SizedBox(height: 10),
                        _agendaBullet(
                          'Nas definições do VS Code ou Cursor activa tgWorkIde.syncToFirestore (na extensão recente já vem ligado por defeito).',
                        ),
                        _agendaBullet(
                          'Executa o comando TG Work IDE: iniciar sessão Firebase e usa a mesma conta com que entraste nesta app.',
                        ),
                        _agendaBullet(
                          'Depois de gravar uma sessão, comando TG Work IDE: abrir registo de diagnóstico — em Saída deve aparecer «Firestore: sessão gravada» ou a mensagem de erro.',
                        ),
                        _agendaBullet(
                          'Cada sessão tem de durar pelo menos tgWorkIde.minSessionSeconds segundos (por defeito 30). Abrir e fechar logo não regista no PC; na nuvem o PATCH pode ficar abaixo do mínimo.',
                        ),
                        _agendaBullet(
                          'Tem de existir pelo menos uma pasta no workspace e fechar bem a janela do IDE (ou mudar de workspace).',
                        ),
                        _agendaBullet(
                          'Firestore: garante índice userId + closedAt (ficheiro tg_work/firestore.indexes.json) e faz deploy indexes + rules.',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ficheiro local no PC (pode existir mesmo com lista vazia aqui): %LOCALAPPDATA%\\TG Work\\ide-sessions\\sessions.jsonl',
                          style: TextStyle(fontSize: 11.5, height: 1.35, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final displayLogs = page.allParsedSessions;
        final completedLogs = page.completedSessions;

        return StreamBuilder<Set<String>>(
          stream: _service.watchIdeAgendaExcludedKeys(uid),
          initialData: const {},
          builder: (context, excludedSnap) {
            final excluded = excludedSnap.data ?? {};
            final filteredDisplayLogs =
                displayLogs.where((l) => !isIdeSessionLogExcluded(l, excluded)).toList();
            final filteredCompletedLogs =
                completedLogs.where((l) => !isIdeSessionLogExcluded(l, excluded)).toList();

        /// Dia de agrupamento: fecho efectivo quando há duração; dia de abertura quando ainda só há stub na nuvem (0 s).
        DateTime groupingDay(IdeSessionLog log) =>
            log.durationSeconds > 0 ? IdeSessionLog.localCalendarDay(log.closedAt) : IdeSessionLog.localCalendarDay(log.openedAt);

        final byDay = <DateTime, List<IdeSessionLog>>{};
        for (final log in filteredDisplayLogs) {
          final d = groupingDay(log);
          byDay.putIfAbsent(d, () => []).add(log);
        }
        final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
        for (final d in days) {
          byDay[d]!.sort((a, b) {
            final ta = a.durationSeconds > 0 ? a.closedAt : a.openedAt;
            final tb = b.durationSeconds > 0 ? b.closedAt : b.openedAt;
            return tb.compareTo(ta);
          });
        }

        final summaries = summarizeIdeSessionsByProject(filteredCompletedLogs, projects)
            .where((s) => !isIdeAgendaAggregateKeyExcluded(s.aggregateKey, excluded))
            .toList();

        // Data de criação do projeto TG Work por id (início real do projeto)
        final kanbanCardStart = <String, DateTime>{
          for (final p in projects) p.id: p.createdAt,
        };

        // Mapas de resolução de labels
        final idToName = {for (final p in projects) p.id: p.name};

        // Para sessões sem tgProjectId, mostra o workspaceName como label do projeto
        String sessionProjectLabel(IdeSessionLog log) {
          final pid = log.tgProjectId.trim();
          if (pid.isNotEmpty) return idToName[pid] ?? pid;
          final ws = log.workspaceName.trim();
          return ws.isNotEmpty ? ws : '—';
        }

        String hm(DateTime t) =>
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

        String dateTimePt(DateTime t) =>
            '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year} · ${hm(t)}';

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Relatório e histórico (nuvem)',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gráfico e tabela por dia: apenas sessões já fechadas com tempo > 0. '
                'Enquanto o IDE está aberto, pode haver linhas com duração 0 s na nuvem até ao fecho. '
                'VS Code e Cursor aparecem no mesmo sítio (campo «editor»).',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: Colors.grey.shade700,
                ),
              ),
              if (page.hasOnlyStubsOrZeroDuration)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Material(
                    color: Colors.deepOrange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: Colors.deepOrange.shade800),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Só aparecem sessões ainda «sem tempo na nuvem» (duração 0 s): é habitual enquanto o IDE está '
                              'aberto no mesmo workspace ou se ainda não houve atualização ao fecho. Ao fechar o Cursor/VS Code, '
                              'verifica Saída → TG Work IDE se há erro de Firebase.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: Colors.grey.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (page.hitQueryLimit)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Limite dos $logsLimit documentos mais recentes atingido em Firestore para esta lista — se faltar histórico antigo é normal.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              StreamBuilder<Map<String, DateTime>>(
                stream: _service.watchProjectFirstExecutionDateMap(),
                initialData: const {},
                builder: (context, execSnap) {
                  final firstExecDate = execSnap.data ?? {};
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IdeSessionProgressiveChart(
                        logs: filteredCompletedLogs,
                        projects: projects
                            .where((p) => !isProjectExcludedFromIdeAgenda(p, excluded))
                            .toList(),
                        execDates: firstExecDate,
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<Map<String, int>>(
                stream: _service.watchAllProjectWorkedSeconds(uid),
                initialData: const {},
                builder: (context, kanbanSnap) {
                  final kanbanSecs = kanbanSnap.data ?? {};

                  // Mapa rápido: tgProjectId -> summary IDE
                  final summaryByProjectId = <String, IdeProjectSessionSummary>{
                    for (final s in summaries)
                      if (s.projectFirestoreId.isNotEmpty) s.projectFirestoreId: s,
                  };
                  final unlinkedSummaries = summaries.where((s) => s.isUnlinked).toList();

                  // Todos os projetos TG Work ordenados: mais recente primeiro
                  final allProjects = projects
                      .where((p) => !isProjectExcludedFromIdeAgenda(p, excluded))
                      .toList()
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                  Widget projectRow(Project project, IdeProjectSessionSummary? ideSummary) {
                    final execStart = firstExecDate[project.id];
                    final isExequivel = project.status == ProjectStatus.exequivel;
                    final firstIde = ideSummary?.earliestIdeSessionDate;

                    // Formata datas curtas DD/MM/AA
                    String fmtD(DateTime d) =>
                        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().substring(2)}';

                    // Pill Kanban — representa o período de trabalho ANTES das sessões IDE.
                    // Para projetos em execução sem registo de transição, usa createdAt
                    // como fallback (igual ao que o Kanban da aba Projetos apresenta).
                    Widget? kanbanPill;
                    if (isExequivel) {
                      // Ainda não entrou em execução: mostra só data de inserção
                      kanbanPill = _KanbanPeriodPill(
                        label: 'Kanban',
                        duration: null,
                        periodLabel: 'Inserido em ${fmtD(project.createdAt)}',
                      );
                    } else {
                      // Usa a data de início de execução registada, ou createdAt como fallback
                      final start = execStart ?? project.createdAt;
                      if (firstIde == null) {
                        // Em execução mas sem sessões IDE ainda: período a decorrer
                        final span = kanbanIdeReportSpanLabelPt(start, DateTime.now());
                        kanbanPill = _KanbanPeriodPill(
                          label: 'Kanban',
                          duration: span,
                          periodLabel: 'desde ${fmtD(start)} → hoje',
                        );
                      } else if (start.isBefore(firstIde)) {
                        // Período Kanban: de start até à 1.ª sessão IDE
                        final span = kanbanIdeReportSpanLabelPt(start, firstIde);
                        kanbanPill = _KanbanPeriodPill(
                          label: 'Kanban',
                          duration: span,
                          periodLabel: '${fmtD(start)} → ${fmtD(firstIde)}',
                        );
                      }
                      // start >= firstIde: projeto entrou em execução depois
                      // de já haver sessões IDE — sem período Kanban pré-IDE
                    }

                    // Total IDE + Kanban (dias de calendário × 8 h/dia)
                    final ideSecs = ideSummary?.totalDurationSeconds ?? 0;
                    final kanbanCalSecs = kanbanWorkSecondsForIdeReport(
                      projectCreatedAt: project.createdAt,
                      execStartDate: execStart,
                      firstIdeSessionAt: firstIde,
                      isExequivel: isExequivel,
                    );
                    final kanbanDays = kanbanIdeReportPeriod(
                      projectCreatedAt: project.createdAt,
                      execStartDate: execStart,
                      firstIdeSessionAt: firstIde,
                      isExequivel: isExequivel,
                    );
                    final totalSecs = ideSecs + kanbanCalSecs;
                    final totalH = totalSecs ~/ 3600;
                    final totalMin = (totalSecs % 3600) ~/ 60;
                    final totalDays = totalSecs ~/ 86400;
                    final totalLabel = totalH > 0
                        ? (totalMin > 0 ? '${totalH}h ${totalMin}min' : '${totalH}h')
                        : (totalMin > 0 ? '${totalMin}min' : '–');
                    final totalDaysLabel = totalDays > 0
                        ? '$totalDays ${totalDays == 1 ? 'dia' : 'dias'}'
                        : null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  project.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                ),
                              ),
                              if (totalSecs > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A237E).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF1A237E).withValues(alpha: 0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        totalLabel,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1A237E),
                                        ),
                                      ),
                                      if (totalDaysLabel != null)
                                        Text(
                                          totalDaysLabel,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: const Color(0xFF1A237E).withValues(alpha: 0.7),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            ideSummary != null
                                ? '${ideSummary.sessionCount} sessões IDE · ${ideSummary.distinctLocalDays} dias'
                                : 'Sem sessões IDE registadas',
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (ideSummary != null)
                                _TimePill(
                                  icon: Icons.terminal,
                                  label: 'IDE',
                                  color: const Color(0xFF1A237E),
                                  seconds: ideSummary.totalDurationSeconds,
                                ),
                              if (kanbanCalSecs > 0 &&
                                  kanbanDays.start != null &&
                                  kanbanDays.end != null)
                                _TimePill(
                                  icon: Icons.view_kanban_outlined,
                                  label: 'Kanban',
                                  color: Colors.teal.shade700,
                                  seconds: kanbanCalSecs,
                                  subtitle:
                                      '${kanbanIdeReportSpanLabelPt(kanbanDays.start!, kanbanDays.end!)} × $kanbanWorkHoursPerCalendarDay h',
                                ),
                              ?kanbanPill,
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  return Card(
                    margin: EdgeInsets.zero,
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Relatório por projeto',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Todos os projetos TG Work · Sessões = vezes que fechaste ou mudaste workspace · '
                            'Kanban = dias desde "Em Execução" até 1.ª sessão IDE × 8 h/dia (no total).',
                            style: TextStyle(fontSize: 11.5, height: 1.3, color: Colors.grey.shade700),
                          ),
                          const Divider(height: 16),
                          // Todos os projetos TG Work
                          for (int i = 0; i < allProjects.length; i++) ...[
                            projectRow(
                              allProjects[i],
                              summaryByProjectId[allProjects[i].id],
                            ),
                            if (i < allProjects.length - 1 || unlinkedSummaries.isNotEmpty)
                              const Divider(height: 14),
                          ],
                          // Workspaces sem projeto ligado
                          if (unlinkedSummaries.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6, top: 2),
                              child: Text(
                                'Workspaces sem projeto ligado',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                              ),
                            ),
                            for (int i = 0; i < unlinkedSummaries.length; i++) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      unlinkedSummaries[i].displayLabel,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${unlinkedSummaries[i].sessionCount} sessões · ${unlinkedSummaries[i].distinctLocalDays} dias',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                    ),
                                    const SizedBox(height: 5),
                                    _TimePill(
                                      icon: Icons.terminal,
                                      label: 'IDE',
                                      color: Colors.blueGrey.shade700,
                                      seconds: unlinkedSummaries[i].totalDurationSeconds,
                                    ),
                                  ],
                                ),
                              ),
                              if (i < unlinkedSummaries.length - 1) const Divider(height: 14),
                            ],
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ), // watchAllProjectWorkedSeconds
                    ],
                  );
                },
              ), // watchProjectFirstExecutionDateMap
              const SizedBox(height: 16),
              Text(
                'Lista por dia',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.blueGrey.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Agrupado por dia local: fecha real quando já há duração; com 0 s, usa‑se o dia da abertura até o IDE fechar '
                '(VS Code ou Cursor — mesma ideia).',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.38,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              for (final day in days) ...[
                Text(
                  '${day.day}/${day.month}/${day.year}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ...byDay[day]!.map(
                  (log) {
                    final pendingCloud = log.durationSeconds <= 0;
                    final closedSameAsStub =
                        pendingCloud &&
                        log.closedAt.difference(log.openedAt).abs().inSeconds < 120;
                    final tileTitle = pendingCloud
                        ? '${sessionProjectLabel(log)} · ${_editorLabelPt(log.editor)} · a decorrer…'
                        : '${sessionProjectLabel(log)} · ${_editorLabelPt(log.editor)} · ${formatWorkDurationSeconds(log.durationSeconds)}';
                    final fechoNuvem = pendingCloud
                        ? (closedSameAsStub
                            ? 'Fecho na nuvem (Firestore): pendente — o instante igual à abertura é normal nesta fase; '
                                'actualiza quando fechares bem o Cursor/VS Code neste workspace.'
                            : 'Fecho na nuvem (Firestore): ainda pendente ou sem duração (0 s) — fecha o IDE para actualizar.')
                        : 'Fecho na nuvem (Firestore): ${dateTimePt(log.closedAt)}';
                    final duraLn = pendingCloud
                        ? 'Duração contabilizada na nuvem: 0 s (aguarda fecho IDE).'
                        : 'Duração contabilizada na nuvem: ${formatWorkDurationSeconds(log.durationSeconds)} (${log.durationSeconds} s)';
                    final tileSub = 'Projeto: ${sessionProjectLabel(log)}\n'
                        'Workspace: ${log.workspaceName}\n'
                        'Abertura: ${dateTimePt(log.openedAt)}\n'
                        '$fechoNuvem\n'
                        '$duraLn\n'
                        'ID documento: ${log.id}';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: pendingCloud ? Colors.orange.shade50 : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: pendingCloud
                              ? Color.lerp(Colors.orange.shade200, Colors.white, 0.35)!
                              : const Color(0x1A1A237E),
                          child: Icon(
                            pendingCloud ? Icons.hourglass_top : Icons.terminal,
                            color: pendingCloud ? Colors.deepOrange.shade900 : Colors.blueGrey[700],
                            size: 20,
                          ),
                        ),
                        title: Text(
                          tileTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: pendingCloud ? Colors.grey.shade900 : null,
                          ),
                        ),
                        subtitle: Text(
                          tileSub,
                          style: TextStyle(
                            height: 1.35,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        isThreeLine: false,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
          },
        );
      },
    );
  }

  Widget _kanbanBoard(String uid) {
    return StreamBuilder<List<IdeScheduleCard>>(
      stream: _service.watchIdeScheduleCards(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Erro Kanban: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }
        final allCards = snapshot.data ?? [];

        return StreamBuilder<Set<String>>(
          stream: _service.watchIdeAgendaExcludedKeys(uid),
          initialData: const {},
          builder: (context, excludedSnap) {
            final excluded = excludedSnap.data ?? {};
            final cards = allCards
                .where((c) => !isIdeScheduleCardExcluded(c, excluded))
                .toList();

        Future<void> onMoved(IdeScheduleCard item, IdeScheduleLane lane) async {
          if (item.lane == lane) return;
          await _service.updateIdeScheduleCardLane(userId: uid, cardId: item.id, lane: lane);
        }

        Widget cardTile(BuildContext context, IdeScheduleCard c) {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Tempo IDE (sessões): ${formatWorkDurationSeconds(c.ideTrackedSeconds)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey.shade800,
                      ),
                    ),
                  ),
                  if (c.workDateIso.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(c.workDateIso, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                    ),
                  if (c.notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(c.notes, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                    ),
                  if (c.tgProjectId.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'ID projeto: ${c.tgProjectId}',
                        style: TextStyle(fontSize: 11, color: Colors.blueGrey[600]),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: Icon(Icons.delete_outline, size: 20, color: Colors.grey[700]),
                      tooltip: 'Remover cartão',
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx2) => AlertDialog(
                            title: const Text('Remover cartão'),
                            content: const Text('Queres remover este cartão da agenda?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx2, false), child: const Text('Não')),
                              TextButton(onPressed: () => Navigator.pop(ctx2, true), child: const Text('Sim')),
                            ],
                          ),
                        );
                        if (ok != true || !mounted) return;
                        try {
                          final key = ideScheduleCardAggregateKey(c);
                          await _service.deleteIdeScheduleCard(userId: uid, cardId: c.id);
                          if (key.isNotEmpty) {
                            await _service.addIdeAgendaExcludedKeys(uid, [key]);
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erro ao remover: $e')),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxWidth > 560 ? 400.0 : 360.0;
            return SizedBox(
              height: h,
              child: StatusKanbanBoard<IdeScheduleCard, IdeScheduleLane>(
                columns: IdeScheduleLane.values,
                labelOf: (l) => l.uiLabelPt,
                colorOf: _laneHeaderColor,
                statusOf: (c) => c.lane,
                items: cards,
                columnWidth: 272,
                onItemMoved: (item, lane) async {
                  await onMoved(item, lane);
                },
                cardBuilder: cardTile,
              ),
            );
          },
        );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    if (uid == null || uid.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Agenda IDE'),
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Inicia sessão para veres a agenda IDE.')),
      );
    }

    return StreamBuilder<List<Project>>(
      stream: _service.getProjects(),
      builder: (context, projSnap) {
        final projects = projSnap.data ?? [];
        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Agenda IDE',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'O objectivo aqui é tempo IDE por projeto, número de sessões e dias em que trabalhaste — '
                  'tanto no VS Code como no Cursor (a mesma extensão TG Work IDE envia os registos).\n'
                  'Segue‑se um Kanban opcional por projeto; o relatório e a lista são a visão mais directa desses números.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
              Padding(padding: const EdgeInsets.only(left: 8, right: 8), child: _kanbanBoard(uid)),
              const Divider(height: 32),
              _sessionsSection(uid, user?.email, projects, _cardsForSync),
            ],
          ),
        );
      },
    );
  }
}

class _KanbanPeriodPill extends StatelessWidget {
  final String label;
  final String? duration;
  final String? periodLabel;

  const _KanbanPeriodPill({
    required this.label,
    required this.duration,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final color = Colors.teal.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.view_kanban_outlined, size: 13, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                duration != null ? '$label: $duration' : label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              if (periodLabel != null)
                Text(
                  periodLabel!,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.75),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int seconds;
  final String? subtitle;

  const _TimePill({
    required this.icon,
    required this.label,
    required this.color,
    required this.seconds,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$label: ${formatWorkDurationSeconds(seconds)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.75),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
