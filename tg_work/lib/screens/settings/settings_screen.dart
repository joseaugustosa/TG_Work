import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/project_type.dart';
import '../../services/firestore_service.dart';

/// Aba Definições: criar e gerir tipos / subtipos de projeto.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final FirestoreService _service;

  @override
  void initState() {
    super.initState();
    _service = FirestoreService();
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

  Future<void> _createType() async {
    if (_uid.isEmpty) return;
    final name = await _askName(title: 'Novo tipo', label: 'Nome do tipo');
    if (name == null) return;
    try {
      await _service.addProjectType(name: name, userId: _uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tipo «$name» criado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteType(ProjectType type) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar tipo'),
        content: Text(
          'Eliminar «${type.name}» e todos os subtipos associados?\n'
          'Os projetos que usam este tipo ficam sem classificação.',
        ),
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
    if (ok != true) return;
    try {
      await _service.deleteProjectType(type.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _createSubtype(ProjectType type) async {
    if (_uid.isEmpty) return;
    final name = await _askName(
      title: 'Novo subtipo',
      label: 'Subtipo de «${type.name}»',
    );
    if (name == null) return;
    try {
      await _service.addProjectSubtype(
        typeId: type.id,
        name: name,
        userId: _uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Subtipo «$name» criado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteSubtype(ProjectSubtype sub) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar subtipo'),
        content: Text('Eliminar «${sub.name}»?'),
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
    if (ok != true) return;
    try {
      await _service.deleteProjectSubtype(sub.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Definições',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Cria aqui os tipos e subtipos dos projetos. '
                'Depois escolhes-os ao criar ou editar um projeto.',
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
                  onPressed: _createType,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo tipo'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<List<ProjectType>>(
            stream: _service.watchProjectTypes(),
            builder: (context, typeSnap) {
              if (typeSnap.hasError) {
                return Center(child: Text('Erro: ${typeSnap.error}'));
              }
              if (!typeSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final types = typeSnap.data ?? [];
              if (types.isEmpty) {
                return Center(
                  child: Text(
                    'Ainda não há tipos.\nClica em «Novo tipo» para começar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
                itemCount: types.length,
                itemBuilder: (context, index) {
                  final type = types[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      key: PageStorageKey('type-${type.id}'),
                      leading: const Icon(
                        Icons.category_outlined,
                        color: Color(0xFF1A237E),
                      ),
                      title: Text(
                        type.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'rename') await _renameType(type);
                          if (v == 'delete') await _deleteType(type);
                          if (v == 'add_sub') await _createSubtype(type);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'add_sub',
                            child: Text('Novo subtipo'),
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
                        StreamBuilder<List<ProjectSubtype>>(
                          stream: _service.watchProjectSubtypes(typeId: type.id),
                          builder: (context, subSnap) {
                            final subs = subSnap.data ?? [];
                            return Column(
                              children: [
                                if (subs.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      12,
                                    ),
                                    child: Text(
                                      'Sem subtipos. Usa o menu ⋮ → Novo subtipo.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ...subs.map(
                                  (s) => ListTile(
                                    contentPadding: const EdgeInsets.only(
                                      left: 56,
                                      right: 8,
                                    ),
                                    leading: const Icon(
                                      Icons.subdirectory_arrow_right,
                                      size: 20,
                                    ),
                                    title: Text(s.name),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (v) async {
                                        if (v == 'rename') {
                                          await _renameSubtype(s);
                                        }
                                        if (v == 'delete') {
                                          await _deleteSubtype(s);
                                        }
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
                                    padding: const EdgeInsets.fromLTRB(
                                      56,
                                      0,
                                      16,
                                      12,
                                    ),
                                    child: TextButton.icon(
                                      onPressed: () => _createSubtype(type),
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
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
