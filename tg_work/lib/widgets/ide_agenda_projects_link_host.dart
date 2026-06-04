import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/ide_schedule_card.dart';
import '../models/ide_session_log.dart';
import '../models/project.dart';
import '../services/firestore_service.dart';
import '../utils/user_display.dart';

/// Mantém a aba Projetos sincronizada com workspaces/cartões da agenda IDE.
class IdeAgendaProjectsLinkHost extends StatefulWidget {
  const IdeAgendaProjectsLinkHost({super.key, required this.child});

  final Widget child;

  @override
  State<IdeAgendaProjectsLinkHost> createState() =>
      _IdeAgendaProjectsLinkHostState();
}

class _IdeAgendaProjectsLinkHostState extends State<IdeAgendaProjectsLinkHost> {
  final _service = FirestoreService();

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<Project>>? _projSub;
  StreamSubscription<IdeSessionLogsQuerySnapshot>? _logsSub;
  StreamSubscription<List<IdeScheduleCard>>? _cardsSub;
  StreamSubscription<Set<String>>? _excludedSub;
  Timer? _debounce;

  String? _uid;
  List<Project> _projects = [];
  List<IdeSessionLog> _logs = [];
  List<IdeSessionLog> _allLogs = [];
  List<IdeScheduleCard> _cards = [];
  Set<String> _excluded = {};

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuth);
    _onAuth(FirebaseAuth.instance.currentUser);
  }

  void _onAuth(User? user) {
    final uid = user?.uid;
    if (uid == null || uid.isEmpty) {
      _disposeStreams();
      return;
    }
    if (_uid == uid && _projSub != null) return;
    _bind(uid);
  }

  void _bind(String uid) {
    _disposeStreams();
    _uid = uid;

    void schedule() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        unawaited(
          _service
              .ensureIdeAgendaLinkedToProjectsTab(
                userId: uid,
                userName: firebaseUserDisplayLabel(
                  FirebaseAuth.instance.currentUser,
                ),
                logs: _logs,
                allLogs: _allLogs,
                cards: _cards,
                projects: _projects,
                excludedAggregateKeys: _excluded,
              )
              .then((created) {
            if (created.length > _projects.length) {
              debugPrint(
                'TG_Work: ${_projects.length} → ${created.length} projetos (agenda IDE → Projetos)',
              );
            }
          }).catchError((Object e, StackTrace st) {
            debugPrint('TG_Work: ligar agenda IDE → Projetos: $e\n$st');
          }),
        );
      });
    }

    _projSub = _service.getProjects().listen((p) {
      _projects = p;
      schedule();
    });
    _logsSub = _service.watchIdeSessionLogs(uid, limit: 2500).listen((page) {
      _logs = page.completedSessions;
      _allLogs = page.allParsedSessions;
      schedule();
    });
    _cardsSub = _service.watchIdeScheduleCards(uid).listen((c) {
      _cards = c;
      schedule();
    });
    _excludedSub = _service.watchIdeAgendaExcludedKeys(uid).listen((keys) {
      _excluded = keys;
      schedule();
    });
  }

  void _disposeStreams() {
    _debounce?.cancel();
    _debounce = null;
    _projSub?.cancel();
    _logsSub?.cancel();
    _cardsSub?.cancel();
    _excludedSub?.cancel();
    _projSub = null;
    _logsSub = null;
    _cardsSub = null;
    _excludedSub = null;
    _uid = null;
    _projects = [];
    _logs = [];
    _allLogs = [];
    _cards = [];
    _excluded = {};
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _disposeStreams();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
