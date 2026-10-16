import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/project_type.dart';
import '../services/firestore_service.dart';

/// Dropdowns Tipo → Área → Subtipo (criados em Definições).
class ProjectClassificationFields extends StatelessWidget {
  final FirestoreService service;
  final String? typeId;
  final String? areaId;
  final String? subtypeId;
  final ValueChanged<ProjectType?> onTypeChanged;
  final ValueChanged<ProjectArea?> onAreaChanged;
  final ValueChanged<ProjectSubtype?> onSubtypeChanged;

  const ProjectClassificationFields({
    super.key,
    required this.service,
    required this.typeId,
    required this.areaId,
    required this.subtypeId,
    required this.onTypeChanged,
    required this.onAreaChanged,
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
                helperText: 'Gere Tipo → Área → Subtipo em Definições',
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
                  onAreaChanged(null);
                  onSubtypeChanged(null);
                  return;
                }
                onTypeChanged(types.firstWhere((x) => x.id == id));
                onAreaChanged(null);
                onSubtypeChanged(null);
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<ProjectArea>>(
              stream: service.watchProjectAreas(typeId: selectedType?.id),
              builder: (context, areaSnap) {
                final areas = selectedType == null
                    ? const <ProjectArea>[]
                    : (areaSnap.data ?? []);
                final selectedAreaId = (areaId ?? '').trim();
                ProjectArea? selectedArea;
                for (final a in areas) {
                  if (a.id == selectedAreaId) {
                    selectedArea = a;
                    break;
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String?>(
                      key: ValueKey(
                        'edit-area-${selectedType?.id}-$selectedAreaId-${areas.length}',
                      ),
                      initialValue: selectedArea?.id,
                      decoration: const InputDecoration(
                        labelText: 'Área',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.layers_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('— Sem área —'),
                        ),
                        ...areas.map(
                          (a) => DropdownMenuItem<String?>(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        ),
                      ],
                      onChanged: selectedType == null
                          ? null
                          : (id) {
                              if (id == null) {
                                onAreaChanged(null);
                                onSubtypeChanged(null);
                                return;
                              }
                              onAreaChanged(
                                areas.firstWhere((x) => x.id == id),
                              );
                              onSubtypeChanged(null);
                            },
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<ProjectSubtype>>(
                      stream: service.watchProjectSubtypes(
                        areaId: selectedArea?.id,
                      ),
                      builder: (context, subSnap) {
                        final subs = selectedArea == null
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
                            'edit-sub-${selectedArea?.id}-$selectedSubtypeId-${subs.length}',
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
                          onChanged: selectedArea == null
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
            ),
          ],
        );
      },
    );
  }
}

/// Filtros Tipo / Área / Subtipo.
class ProjectClassificationFilters extends StatelessWidget {
  final FirestoreService service;
  final String? typeId;
  final String? areaId;
  final String? subtypeId;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onAreaChanged;
  final ValueChanged<String?> onSubtypeChanged;

  const ProjectClassificationFilters({
    super.key,
    required this.service,
    required this.typeId,
    required this.areaId,
    required this.subtypeId,
    required this.onTypeChanged,
    required this.onAreaChanged,
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

        return Column(
          children: [
            DropdownButtonFormField<String?>(
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
                onAreaChanged(null);
                onSubtypeChanged(null);
              },
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<ProjectArea>>(
              stream: service.watchProjectAreas(typeId: effectiveType),
              builder: (context, areaSnap) {
                final areas = effectiveType == null
                    ? const <ProjectArea>[]
                    : (areaSnap.data ?? []);
                final aidRaw = (areaId ?? '').trim();
                final areaOk =
                    aidRaw.isNotEmpty && areas.any((a) => a.id == aidRaw);
                final effectiveArea = areaOk ? aidRaw : null;

                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        key: ValueKey(
                          'filter-area-$effectiveType-$effectiveArea-${areas.length}',
                        ),
                        initialValue: effectiveArea,
                        isDense: true,
                        decoration: const InputDecoration(
                          labelText: 'Área',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todas'),
                          ),
                          ...areas.map(
                            (a) => DropdownMenuItem<String?>(
                              value: a.id,
                              child:
                                  Text(a.name, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: effectiveType == null
                            ? null
                            : (v) {
                                onAreaChanged(v);
                                onSubtypeChanged(null);
                              },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StreamBuilder<List<ProjectSubtype>>(
                        stream: service.watchProjectSubtypes(
                          areaId: effectiveArea,
                        ),
                        builder: (context, subSnap) {
                          final subs = effectiveArea == null
                              ? const <ProjectSubtype>[]
                              : (subSnap.data ?? []);
                          final sid = (subtypeId ?? '').trim();
                          final subOk =
                              sid.isNotEmpty && subs.any((s) => s.id == sid);
                          final effectiveSub = subOk ? sid : null;

                          return DropdownButtonFormField<String?>(
                            key: ValueKey(
                              'filter-sub-$effectiveArea-$effectiveSub-${subs.length}',
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
                                  child: Text(
                                    s.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: effectiveArea == null
                                ? null
                                : onSubtypeChanged,
                          );
                        },
                      ),
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

List<Project> filterProjectsByClassification(
  List<Project> projects, {
  String? typeId,
  String? areaId,
  String? subtypeId,
}) {
  final t = typeId?.trim() ?? '';
  final a = areaId?.trim() ?? '';
  final s = subtypeId?.trim() ?? '';
  return projects.where((p) {
    if (t.isNotEmpty && p.projectTypeId.trim() != t) return false;
    if (a.isNotEmpty && p.projectAreaId.trim() != a) return false;
    if (s.isNotEmpty && p.projectSubtypeId.trim() != s) return false;
    return true;
  }).toList();
}
