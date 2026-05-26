import 'dart:async';

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/firestore_service.dart';
import '../utils/windows_firestore_compat.dart';

/// Ao abrir o detalhe do projeto: inicia o relógio de trabalho (mobile); ao sair: para e grava.
/// Só inicia automaticamente se [projectStatus] == [ProjectStatus.emExecucao].
/// No desktop Windows o auto-start está desativado.
class ProjectWorkspaceTimerHost extends StatefulWidget {
  final String userId;
  final String projectId;
  final ProjectStatus projectStatus;
  final Widget child;

  const ProjectWorkspaceTimerHost({
    super.key,
    required this.userId,
    required this.projectId,
    required this.projectStatus,
    required this.child,
  });

  @override
  State<ProjectWorkspaceTimerHost> createState() =>
      _ProjectWorkspaceTimerHostState();
}

class _ProjectWorkspaceTimerHostState extends State<ProjectWorkspaceTimerHost> {
  final _firestore = FirestoreService();

  bool get _timerAllowed =>
      !disableManualWorkTimerOnDesktop &&
      widget.projectStatus == ProjectStatus.emExecucao;

  @override
  void initState() {
    super.initState();
    if (_timerAllowed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoStart());
    }
  }

  Future<void> _autoStart() async {
    if (!_timerAllowed) return;
    if (!mounted || widget.userId.isEmpty) return;
    try {
      await _firestore.startProjectWorkTimer(widget.userId, widget.projectId);
    } catch (e, st) {
      debugPrint('TG_Work: auto-start relógio: $e\n$st');
    }
  }

  @override
  void dispose() {
    if (_timerAllowed) {
      final uid = widget.userId;
      final pid = widget.projectId;
      if (uid.isNotEmpty && pid.isNotEmpty) {
        unawaited(_firestore.stopProjectWorkTimerIfMatchingProject(uid, pid));
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
