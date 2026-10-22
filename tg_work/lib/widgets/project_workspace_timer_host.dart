import 'package:flutter/material.dart';

import '../models/project.dart';

/// Envolve o detalhe do projeto. O relógio é só manual (Arrancar / Pausar / Parar / Gravar)
/// — já não inicia nem pára automaticamente ao abrir/sair do ecrã.
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
  @override
  Widget build(BuildContext context) => widget.child;
}
