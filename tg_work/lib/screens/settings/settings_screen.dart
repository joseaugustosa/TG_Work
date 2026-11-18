import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/project_type.dart';
import '../../services/firestore_service.dart';
import 'admin_users_section.dart';

/// Aba Definições: Empresa → Tipo → Área → Subtipo.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final FirestoreService _service;
  bool _ensuredDefaultCompany = false;

  @override
  void initState() {
    super.initState();
    _service = FirestoreService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureGeral());
  }

  Future<void> _ensureGeral() async {
    if (_ensuredDefaultCompany || _uid.isEmpty) return;
    _ensuredDefaultCompany = true;
    try {
      await _service.ensureDefaultCompany(userId: _uid);
    } catch (e) {
      debugPrint('TG_Work: ensureDefaultCompany: $e');
    }
  }

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<String?> _askName({
    required String title,
    required String label,
    String initial = '',
  }) async {
    final ctrl = TextEditingController(text: initial);
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
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    final name = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || name.isEmpty) return null;
    return name;
  }

  Future<bool> _confirmDelete(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _createCompany() async {
    if (_uid.isEmpty) return;
    final name =
        await _askName(title: 'Nova empresa', label: 'Nome da empresa');
    if (name == null) return;
    try {
      await _service.addProjectCompany(name: name, userId: _uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Empresa «$name» criada.')),
        );
      }
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _renameCompany(ProjectCompany company) async {
    final name = await _askName(
      title: 'Renomear empresa',
      label: 'Nome da empresa',
      initial: company.name,
    );
    if (name == null || name == company.name) return;
    try {
      await _service.renameProjectCompany(company.id, name);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteCompany(ProjectCompany company) async {
    final ok = await _confirmDelete(
      'Eliminar empresa',
      'Eliminar «${company.name}», todos os tipos, áreas e subtipos?\n'
      'Os projetos que usam esta empresa ficam sem classificação.',
    );
    if (!ok) return;
    try {
      await _service.deleteProjectCompany(company.id);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _createType(ProjectCompany company) async {
    if (_uid.isEmpty) return;
    final name = await _askName(
      title: 'Novo tipo',
      label: 'Tipo de «${company.name}»',
    );
    if (name == null) return;
    try {
      await _service.addProjectType(
        name: name,
        userId: _uid,
        companyId: company.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tipo «$name» criado.')),
        );
      }
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _renameType(ProjectType type) async {
    final name = await _askName(
      title: 'Renomear tipo',
      label: 'Nome do tipo',
      initial: type.name,
    );
    if (name == null || name == type.name) return;
    try {
      await _service.renameProjectType(type.id, name);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteType(ProjectType type) async {
    final ok = await _confirmDelete(
      'Eliminar tipo',
      'Eliminar «${type.name}», todas as áreas e subtipos?\n'
      'Os projetos que usam este tipo ficam sem classificação.',
    );
    if (!ok) return;
    try {
      await _service.deleteProjectType(type.id);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _createArea(ProjectType type) async {
    if (_uid.isEmpty) return;
    final name = await _askName(
      title: 'Nova área',
      label: 'Área de «${type.name}»',
    );
    if (name == null) return;
    try {
      await _service.addProjectArea(
        typeId: type.id,
        name: name,
        userId: _uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Área «$name» criada.')),
        );
      }
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _renameArea(ProjectArea area) async {
    final name = await _askName(
      title: 'Renomear área',
      label: 'Nome da área',
      initial: area.name,
    );
    if (name == null || name == area.name) return;
    try {
      await _service.renameProjectArea(area.id, name);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteArea(ProjectArea area) async {
    final ok = await _confirmDelete(
      'Eliminar área',
      'Eliminar «${area.name}» e os subtipos dentro dela?',
    );
    if (!ok) return;
    try {
      await _service.deleteProjectArea(area.id);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _createSubtype(ProjectType type, ProjectArea area) async {
    if (_uid.isEmpty) return;
    final name = await _askName(
      title: 'Novo subtipo',
      label: 'Subtipo de «${area.name}»',
    );
    if (name == null) return;
    try {
      await _service.addProjectSubtype(
        typeId: type.id,
        areaId: area.id,
        name: name,
        userId: _uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Subtipo «$name» criado.')),
        );
      }
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _renameSubtype(ProjectSubtype sub) async {
    final name = await _askName(
      title: 'Renomear subtipo',
      label: 'Nome do subtipo',
      initial: sub.name,
    );
    if (name == null || name == sub.name) return;
    try {
      await _service.renameProjectSubtype(sub.id, name);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteSubtype(ProjectSubtype sub) async {
    final ok = await _confirmDelete(
      'Eliminar subtipo',
      'Eliminar «${sub.name}»?',
    );
    if (!ok) return;
    try {
      await _service.deleteProjectSubtype(sub.id);
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminUsersSection(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Definições de projeto',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hierarquia: Empresa → Tipo → Área → Subtipo. '
                  'Depois escolhes isto ao criar ou editar um projeto.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _createCompany,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Nova empresa'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<ProjectCompany>>(
            stream: _service.watchProjectCompanies(),
            builder: (context, companySnap) {
              if (companySnap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Erro: ${companySnap.error}',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              if (!companySnap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final companies = companySnap.data ?? [];
              if (companies.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Ainda não há empresas.\nClica em «Nova empresa» para começar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Column(
                  children: [
                    for (final company in companies)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          key: PageStorageKey('company-${company.id}'),
                          leading: const Icon(
                            Icons.business_outlined,
                            color: Color(0xFF1A237E),
                          ),
                          title: Text(
                            company.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Empresa',
                            style: TextStyle(fontSize: 11),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'add_type') await _createType(company);
                              if (v == 'rename') await _renameCompany(company);
                              if (v == 'delete') await _deleteCompany(company);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'add_type',
                                child: Text('Novo tipo'),
                              ),
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('Renomear'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Eliminar'),
                              ),
                            ],
                          ),
                          children: [
                            StreamBuilder<List<ProjectType>>(
                              stream: _service.watchProjectTypes(
                                companyId: company.id,
                              ),
                              builder: (context, typeSnap) {
                                final types = typeSnap.data ?? [];
                                return Column(
                                  children: [
                                    if (types.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          8,
                                        ),
                                        child: Text(
                                          'Sem tipos. Usa o menu ⋮ → Novo tipo.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ...types.map(
                                      (type) => _TypeTile(
                                        type: type,
                                        service: _service,
                                        onCreateArea: () => _createArea(type),
                                        onRenameType: () => _renameType(type),
                                        onDeleteType: () => _deleteType(type),
                                        onCreateSubtype: (area) =>
                                            _createSubtype(type, area),
                                        onRenameArea: _renameArea,
                                        onDeleteArea: _deleteArea,
                                        onRenameSubtype: _renameSubtype,
                                        onDeleteSubtype: _deleteSubtype,
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          24,
                                          0,
                                          16,
                                          12,
                                        ),
                                        child: TextButton.icon(
                                          onPressed: () =>
                                              _createType(company),
                                          icon: const Icon(Icons.add, size: 18),
                                          label: const Text('Novo tipo'),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  final ProjectType type;
  final FirestoreService service;
  final VoidCallback onCreateArea;
  final VoidCallback onRenameType;
  final VoidCallback onDeleteType;
  final Future<void> Function(ProjectArea) onCreateSubtype;
  final Future<void> Function(ProjectArea) onRenameArea;
  final Future<void> Function(ProjectArea) onDeleteArea;
  final Future<void> Function(ProjectSubtype) onRenameSubtype;
  final Future<void> Function(ProjectSubtype) onDeleteSubtype;

  const _TypeTile({
    required this.type,
    required this.service,
    required this.onCreateArea,
    required this.onRenameType,
    required this.onDeleteType,
    required this.onCreateSubtype,
    required this.onRenameArea,
    required this.onDeleteArea,
    required this.onRenameSubtype,
    required this.onDeleteSubtype,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: PageStorageKey('type-${type.id}'),
      tilePadding: const EdgeInsets.only(left: 28, right: 8),
      leading: const Icon(Icons.category_outlined, color: Color(0xFF3949AB)),
      title: Text(type.name),
      subtitle: const Text('Tipo', style: TextStyle(fontSize: 11)),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'add_area') onCreateArea();
          if (v == 'rename') onRenameType();
          if (v == 'delete') onDeleteType();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'add_area', child: Text('Nova área')),
          PopupMenuItem(value: 'rename', child: Text('Renomear')),
          PopupMenuItem(value: 'delete', child: Text('Eliminar')),
        ],
      ),
      children: [
        StreamBuilder<List<ProjectArea>>(
          stream: service.watchProjectAreas(typeId: type.id),
          builder: (context, areaSnap) {
            final areas = areaSnap.data ?? [];
            return Column(
              children: [
                if (areas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(48, 0, 16, 8),
                    child: Text(
                      'Sem áreas. Usa o menu ⋮ → Nova área.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ...areas.map(
                  (area) => _AreaTile(
                    type: type,
                    area: area,
                    service: service,
                    onCreateSubtype: () => onCreateSubtype(area),
                    onRenameArea: () => onRenameArea(area),
                    onDeleteArea: () => onDeleteArea(area),
                    onRenameSubtype: onRenameSubtype,
                    onDeleteSubtype: onDeleteSubtype,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(48, 0, 16, 12),
                    child: TextButton.icon(
                      onPressed: onCreateArea,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nova área'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AreaTile extends StatelessWidget {
  final ProjectType type;
  final ProjectArea area;
  final FirestoreService service;
  final VoidCallback onCreateSubtype;
  final VoidCallback onRenameArea;
  final VoidCallback onDeleteArea;
  final Future<void> Function(ProjectSubtype) onRenameSubtype;
  final Future<void> Function(ProjectSubtype) onDeleteSubtype;

  const _AreaTile({
    required this.type,
    required this.area,
    required this.service,
    required this.onCreateSubtype,
    required this.onRenameArea,
    required this.onDeleteArea,
    required this.onRenameSubtype,
    required this.onDeleteSubtype,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: PageStorageKey('area-${area.id}'),
      tilePadding: const EdgeInsets.only(left: 48, right: 8),
      leading: const Icon(Icons.layers_outlined, color: Color(0xFF5C6BC0)),
      title: Text(area.name),
      subtitle: const Text('Área', style: TextStyle(fontSize: 11)),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'add_sub') onCreateSubtype();
          if (v == 'rename') onRenameArea();
          if (v == 'delete') onDeleteArea();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'add_sub', child: Text('Novo subtipo')),
          PopupMenuItem(value: 'rename', child: Text('Renomear')),
          PopupMenuItem(value: 'delete', child: Text('Eliminar')),
        ],
      ),
      children: [
        StreamBuilder<List<ProjectSubtype>>(
          stream: service.watchProjectSubtypes(areaId: area.id),
          builder: (context, subSnap) {
            final subs = subSnap.data ?? [];
            return Column(
              children: [
                if (subs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
                    child: Text(
                      'Sem subtipos nesta área.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ...subs.map(
                  (s) => ListTile(
                    contentPadding: const EdgeInsets.only(left: 72, right: 8),
                    leading: const Icon(
                      Icons.subdirectory_arrow_right,
                      size: 20,
                    ),
                    title: Text(s.name),
                    subtitle: const Text(
                      'Subtipo',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'rename') await onRenameSubtype(s);
                        if (v == 'delete') await onDeleteSubtype(s);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text('Renomear'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Eliminar'),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
                    child: TextButton.icon(
                      onPressed: onCreateSubtype,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Novo subtipo'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
