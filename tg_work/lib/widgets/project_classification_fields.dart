import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/project_type.dart';
import '../services/firestore_service.dart';

/// Dropdowns Tipo / Subtipo com opção de criar novos (pelo utilizador).
class ProjectClassificationFields extends StatelessWidget {
  final FirestoreService service;
  final String? typeId;
  final String? subtypeId;
  final ValueChanged<ProjectType?> onTypeChanged;
  final ValueChanged<ProjectSubtype?> onSubtypeChanged;

  const ProjectClassificationFields({
    super.key,
    required this.service,
    required this.typeId,
    required this.subtypeId,
    required this.onTypeChanged,
    required this.onSubtypeChanged,
  });

  Future<void> _createType(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    final name = await _askName(context, title: 'Novo tipo', label: 'Nome do tipo');
    if (name == null || name.isEmpty) return;
    try {
      final id = await service.addProjectType(name: name, userId: uid);
      onTypeChanged(
        ProjectType(
          id: id,
          name: name,
          createdBy: uid,
          createdAt: DateTime.now(),
        ),
      );
      onSubtypeChanged(null);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar tipo: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _createSubtype(BuildContext context, String typeId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty || typeId.isEmpty) return;
    final name =
        await _askName(context, title: 'Novo subtipo', label: 'Nome do subtipo');
    if (name == null || name.isEmpty) return;
    try {
      final id = await service.addProjectSubtype(
        typeId: typeId,
        name: name,
        userId: uid,
      );
      onSubtypeChanged(
        ProjectSubtype(
          id: id,
          typeId: typeId,
          name: name,
          createdBy: uid,
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar subtipo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _askName(
    BuildContext context, {
    required String title,
    required String label,
  }) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    final name = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || name.isEmpty) return null;
    return name;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProjectType>>(
      stream: service.watchProjectTypes(),
      builder: (context, typeSnap) {
        final types = typeSnap.data ?? [];
        final selectedTypeId = (typeId ?? '').trim();
        ProjectType? selectedType;
        for (final t in types) {
          if (t.id == selectedTypeId) {
            selectedType = t;
            break;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey('edit-type-$selectedTypeId-${types.length}'),
                    initialValue: selectedType?.id,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('— Sem tipo —'),
                      ),
                      ...types.map(
                        (t) => DropdownMenuItem<String?>(
                          value: t.id,
                          child: Text(t.name),
                        ),
                      ),
                    ],
                    onChanged: (id) {
                      if (id == null) {
                        onTypeChanged(null);
                        onSubtypeChanged(null);
                        return;
                      }
                      final t = types.firstWhere((x) => x.id == id);
                      onTypeChanged(t);
                      onSubtypeChanged(null);
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Criar tipo',
                  onPressed: () => _createType(context),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<ProjectSubtype>>(
              stream: service.watchProjectSubtypes(
                typeId: selectedType?.id,
              ),
              builder: (context, subSnap) {
                final subs = selectedType == null
                    ? const <ProjectSubtype>[]
                    : (subSnap.data ?? []);
                final selectedSubtypeId = (subtypeId ?? '').trim();
                ProjectSubtype? selectedSubtype;
                for (final s in subs) {
                  if (s.id == selectedSubtypeId) {
                    selectedSubtype = s;
                    break;
                  }
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        key: ValueKey(
                          'edit-sub-${selectedType?.id}-$selectedSubtypeId-${subs.length}',
                        ),
                        initialValue: selectedSubtype?.id,
                        decoration: const InputDecoration(
                          labelText: 'Subtipo',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.subdirectory_arrow_right),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('— Sem subtipo —'),
                          ),
                          ...subs.map(
                            (s) => DropdownMenuItem<String?>(
                              value: s.id,
                              child: Text(s.name),
                            ),
                          ),
                        ],
                        onChanged: selectedType == null
                            ? null
                            : (id) {
                                if (id == null) {
                                  onSubtypeChanged(null);
                                  return;
                                }
                                onSubtypeChanged(
                                  subs.firstWhere((x) => x.id == id),
                                );
                              },
                      ),
                    ),
                    IconButton(
                      tooltip: selectedType == null
                          ? 'Escolhe um tipo primeiro'
                          : 'Criar subtipo',
                      onPressed: selectedType == null
                          ? null
                          : () => _createSubtype(context, selectedType!.id),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Filtros de pesquisa por tipo / subtipo (criados pelo utilizador).
class ProjectClassificationFilters extends StatelessWidget {
  final FirestoreService service;
  final String? typeId;
  final String? subtypeId;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onSubtypeChanged;

  const ProjectClassificationFilters({
    super.key,
    required this.service,
    required this.typeId,
    required this.subtypeId,
    required this.onTypeChanged,
    required this.onSubtypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProjectType>>(
      stream: service.watchProjectTypes(),
      builder: (context, typeSnap) {
        final types = typeSnap.data ?? [];
        final tid = (typeId ?? '').trim();
        final typeOk = tid.isNotEmpty && types.any((t) => t.id == tid);
        final effectiveType = typeOk ? tid : null;

        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: ValueKey('filter-type-$effectiveType-${types.length}'),
                initialValue: effectiveType,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todos'),
                  ),
                  ...types.map(
                    (t) => DropdownMenuItem<String?>(
                      value: t.id,
                      child: Text(t.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) {
                  onTypeChanged(v);
                  onSubtypeChanged(null);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StreamBuilder<List<ProjectSubtype>>(
                stream: service.watchProjectSubtypes(typeId: effectiveType),
                builder: (context, subSnap) {
                  final subs = effectiveType == null
                      ? const <ProjectSubtype>[]
                      : (subSnap.data ?? []);
                  final sid = (subtypeId ?? '').trim();
                  final subOk =
                      sid.isNotEmpty && subs.any((s) => s.id == sid);
                  final effectiveSub = subOk ? sid : null;

                  return DropdownButtonFormField<String?>(
                    key: ValueKey(
                      'filter-sub-$effectiveType-$effectiveSub-${subs.length}',
                    ),
                    initialValue: effectiveSub,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Subtipo',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todos'),
                      ),
                      ...subs.map(
                        (s) => DropdownMenuItem<String?>(
                          value: s.id,
                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: effectiveType == null ? null : onSubtypeChanged,
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

List<Project> filterProjectsByClassification(
  List<Project> projects, {
  String? typeId,
  String? subtypeId,
}) {
  final t = typeId?.trim() ?? '';
  final s = subtypeId?.trim() ?? '';
  return projects.where((p) {
    if (t.isNotEmpty && p.projectTypeId.trim() != t) return false;
    if (s.isNotEmpty && p.projectSubtypeId.trim() != s) return false;
    return true;
  }).toList();
}
