import 'package:flutter/material.dart';

import '../../models/project.dart';
import '../../services/firestore_service.dart';
import '../../widgets/project_tree_panel.dart';

/// Aba «Árvore»: todos os projetos com dependências e vistos de execução/conclusão.
class TreeTabScreen extends StatefulWidget {
  const TreeTabScreen({super.key});

  @override
  State<TreeTabScreen> createState() => _TreeTabScreenState();
}

class _TreeTabScreenState extends State<TreeTabScreen> {
  late final FirestoreService _service;
  late final Stream<List<Project>> _projectsStream;
  String? _filterProjectId;

  @override
  void initState() {
    super.initState();
    _service = FirestoreService();
    _projectsStream = _service.getProjects();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Project>>(
      stream: _projectsStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erro ao carregar projetos: ${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final projects = snap.data ?? [];
        if (projects.isEmpty) {
          return Center(
            child: Text(
              'Ainda não há projetos.\nCria um na aba Projetos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
          );
        }

        final filterOk = _filterProjectId != null &&
            projects.any((p) => p.id == _filterProjectId);
        final effectiveFilter = filterOk ? _filterProjectId : null;
        final filtered = effectiveFilter == null
            ? projects
            : projects.where((p) => p.id == effectiveFilter).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Árvore',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nome do projeto, temas, desenvolvimentos e notas. '
                    'Usa as caixas para marcar execução (projeto/tema/desenvolvimento) '
                    'e conclusão (notas).',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    key: ValueKey<String?>(effectiveFilter),
                    initialValue: effectiveFilter,
                    decoration: const InputDecoration(
                      labelText: 'Projeto',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.filter_list),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todos os projetos'),
                      ),
                      ...projects.map(
                        (p) => DropdownMenuItem<String?>(
                          value: p.id,
                          child: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _filterProjectId = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final project = filtered[index];
                  return ProjectTreePanel(
                    key: ValueKey(project.id),
                    project: project,
                    initiallyExpanded:
                        filtered.length == 1 || index == 0,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
