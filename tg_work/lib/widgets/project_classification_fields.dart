import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/project_type.dart';
import '../services/firestore_service.dart';

/// Dropdowns Empresa → Tipo → Área → Subtipo (criados em Definições).
class ProjectClassificationFields extends StatelessWidget {
  final FirestoreService service;
  final String? companyId;
  final String? typeId;
  final String? areaId;
  final String? subtypeId;
  final ValueChanged<ProjectCompany?> onCompanyChanged;
  final ValueChanged<ProjectType?> onTypeChanged;
  final ValueChanged<ProjectArea?> onAreaChanged;
  final ValueChanged<ProjectSubtype?> onSubtypeChanged;

  const ProjectClassificationFields({
    super.key,
    required this.service,
    required this.companyId,
    required this.typeId,
    required this.areaId,
    required this.subtypeId,
    required this.onCompanyChanged,
    required this.onTypeChanged,
    required this.onAreaChanged,
    required this.onSubtypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProjectCompany>>(
      stream: service.watchProjectCompanies(),
      builder: (context, companySnap) {
        final companies = companySnap.data ?? [];
        final selectedCompanyId = (companyId ?? '').trim();
        ProjectCompany? selectedCompany;
        for (final c in companies) {
          if (c.id == selectedCompanyId) {
            selectedCompany = c;
            break;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String?>(
              key: ValueKey(
                'edit-company-$selectedCompanyId-${companies.length}',
              ),
              initialValue: selectedCompany?.id,
              decoration: const InputDecoration(
                labelText: 'Empresa',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business_outlined),
                helperText:
                    'Gere Empresa → Tipo → Área → Subtipo em Definições',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— Sem empresa —'),
                ),
                ...companies.map(
                  (c) => DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text(c.name),
                  ),
                ),
              ],
              onChanged: (id) {
                if (id == null) {
                  onCompanyChanged(null);
                  onTypeChanged(null);
                  onAreaChanged(null);
                  onSubtypeChanged(null);
                  return;
                }
                onCompanyChanged(companies.firstWhere((x) => x.id == id));
                onTypeChanged(null);
                onAreaChanged(null);
                onSubtypeChanged(null);
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<ProjectType>>(
              stream: service.watchProjectTypes(
                companyId: selectedCompany?.id,
              ),
              builder: (context, typeSnap) {
                final types = selectedCompany == null
                    ? const <ProjectType>[]
                    : (typeSnap.data ?? []);
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
                      key: ValueKey(
                        'edit-type-${selectedCompany?.id}-$selectedTypeId-${types.length}',
                      ),
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
                      onChanged: selectedCompany == null
                          ? null
                          : (id) {
                              if (id == null) {
                                onTypeChanged(null);
                                onAreaChanged(null);
                                onSubtypeChanged(null);
                                return;
                              }
                              onTypeChanged(
                                types.firstWhere((x) => x.id == id),
                              );
                              onAreaChanged(null);
                              onSubtypeChanged(null);
                            },
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<ProjectArea>>(
                      stream: service.watchProjectAreas(
                        typeId: selectedType?.id,
                      ),
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
                                final selectedSubtypeId =
                                    (subtypeId ?? '').trim();
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
                                    prefixIcon: Icon(
                                      Icons.subdirectory_arrow_right,
                                    ),
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
            ),
          ],
        );
      },
    );
  }
}

/// Filtros Empresa / Tipo / Área / Subtipo.
class ProjectClassificationFilters extends StatelessWidget {
  final FirestoreService service;
  final String? companyId;
  final String? typeId;
  final String? areaId;
  final String? subtypeId;
  final ValueChanged<String?> onCompanyChanged;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onAreaChanged;
  final ValueChanged<String?> onSubtypeChanged;

  const ProjectClassificationFilters({
    super.key,
    required this.service,
    required this.companyId,
    required this.typeId,
    required this.areaId,
    required this.subtypeId,
    required this.onCompanyChanged,
    required this.onTypeChanged,
    required this.onAreaChanged,
    required this.onSubtypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProjectCompany>>(
      stream: service.watchProjectCompanies(),
      builder: (context, companySnap) {
        final companies = companySnap.data ?? [];
        final cid = (companyId ?? '').trim();
        final companyOk =
            cid.isNotEmpty && companies.any((c) => c.id == cid);
        final effectiveCompany = companyOk ? cid : null;

        return Column(
          children: [
            DropdownButtonFormField<String?>(
              key: ValueKey(
                'filter-company-$effectiveCompany-${companies.length}',
              ),
              initialValue: effectiveCompany,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Empresa',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todas'),
                ),
                ...companies.map(
                  (c) => DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) {
                onCompanyChanged(v);
                onTypeChanged(null);
                onAreaChanged(null);
                onSubtypeChanged(null);
              },
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<ProjectType>>(
              stream: service.watchProjectTypes(companyId: effectiveCompany),
              builder: (context, typeSnap) {
                final types = effectiveCompany == null
                    ? const <ProjectType>[]
                    : (typeSnap.data ?? []);
                final tid = (typeId ?? '').trim();
                final typeOk =
                    tid.isNotEmpty && types.any((t) => t.id == tid);
                final effectiveType = typeOk ? tid : null;

                return Column(
                  children: [
                    DropdownButtonFormField<String?>(
                      key: ValueKey(
                        'filter-type-$effectiveCompany-$effectiveType-${types.length}',
                      ),
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
                            child:
                                Text(t.name, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: effectiveCompany == null
                          ? null
                          : (v) {
                              onTypeChanged(v);
                              onAreaChanged(null);
                              onSubtypeChanged(null);
                            },
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<ProjectArea>>(
                      stream:
                          service.watchProjectAreas(typeId: effectiveType),
                      builder: (context, areaSnap) {
                        final areas = effectiveType == null
                            ? const <ProjectArea>[]
                            : (areaSnap.data ?? []);
                        final aidRaw = (areaId ?? '').trim();
                        final areaOk = aidRaw.isNotEmpty &&
                            areas.any((a) => a.id == aidRaw);
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
                                      child: Text(
                                        a.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
                                  final subOk = sid.isNotEmpty &&
                                      subs.any((s) => s.id == sid);
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
            ),
          ],
        );
      },
    );
  }
}

List<Project> filterProjectsByClassification(
  List<Project> projects, {
  String? companyId,
  String? typeId,
  String? areaId,
  String? subtypeId,
}) {
  final c = companyId?.trim() ?? '';
  final t = typeId?.trim() ?? '';
  final a = areaId?.trim() ?? '';
  final s = subtypeId?.trim() ?? '';
  return projects.where((p) {
    if (c.isNotEmpty && p.projectCompanyId.trim() != c) return false;
    if (t.isNotEmpty && p.projectTypeId.trim() != t) return false;
    if (a.isNotEmpty && p.projectAreaId.trim() != a) return false;
    if (s.isNotEmpty && p.projectSubtypeId.trim() != s) return false;
    return true;
  }).toList();
}
