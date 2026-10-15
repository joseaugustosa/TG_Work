import 'package:flutter/material.dart';

import '../../models/project.dart';
import '../../widgets/project_tree_panel.dart';

/// Ecrã dedicado à árvore de um único projeto (aberto a partir do detalhe).
class ProjectTreeScreen extends StatelessWidget {
  final Project project;

  const ProjectTreeScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Árvore do projeto',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              project.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          Text(
            'Expande os nós e usa o visto para marcar execução '
            '(projeto, temas, desenvolvimentos) e conclusão das notas.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          ProjectTreePanel(
            project: project,
            initiallyExpanded: true,
          ),
        ],
      ),
    );
  }
}
