import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/project_type.dart';
import '../services/firestore_service.dart';

/// Dropdowns Tipo / Subtipo (criados em Definições).
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
            DropdownButtonFormField<String?>(
              key: ValueKey('edit-type-$selectedTypeId-${types.length}'),
              initialValue: selectedType?.id,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_outlined),
                helperText: 'Gere tipos e subtipos na aba Definições',
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

                return DropdownButtonFormField<String?>(
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
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Filtros de pesquisa por tipo / subtipo.
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
