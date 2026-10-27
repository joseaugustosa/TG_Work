import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/admin_user_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

/// Gestão de administradores e utilizadores (visível a admins / bootstrap).
class AdminUsersSection extends StatefulWidget {
  const AdminUsersSection({super.key});

  @override
  State<AdminUsersSection> createState() => _AdminUsersSectionState();
}

class _AdminUsersSectionState extends State<AdminUsersSection> {
  final _fs = FirestoreService();
  final _auth = AuthService();
  final _adminUsers = AdminUserService();
  bool _busy = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  Future<void> _syncUsers() async {
    setState(() => _busy = true);
    try {
      final n = await _fs.syncUsersFromFirestoreActivity();
      _toast(
        n == 0
            ? 'Nenhum utilizador novo encontrado no Firestore.'
            : 'Importados $n utilizador(es) já presentes no Firebase.',
      );
    } catch (e) {
      _toast('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claimAdmin() async {
    setState(() => _busy = true);
    try {
      await _fs.claimFirstAdmin(_uid);
      _toast('És agora administrador da app.');
    } catch (e) {
      _toast('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createUser({required bool asAdmin}) async {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    var obscure = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(asAdmin ? 'Novo administrador' : 'Novo utilizador'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Palavra-passe (mín. 6)',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setLocal(() => obscure = !obscure),
                        ),
                      ),
                    ),
                  ],
                ),
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
            );
          },
        );
      },
    );

    final email = emailCtrl.text.trim();
    final name = nameCtrl.text.trim();
    final pass = passCtrl.text;
    emailCtrl.dispose();
    nameCtrl.dispose();
    passCtrl.dispose();
    if (ok != true) return;
    if (email.isEmpty || pass.length < 6) {
      _toast('Email e palavra-passe (mín. 6) são obrigatórios.', error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final created = await _auth.createUserWithoutSwitchingSession(
        email: email,
        password: pass,
        displayName: name,
      );
      await _fs.writeAppUserProfile(
        AppUser(
          id: created.uid,
          email: email,
          displayName: name.isEmpty ? (created.displayName ?? '') : name,
          role: asAdmin ? AppUserRole.admin : AppUserRole.user,
          blocked: false,
          deleted: false,
          createdAt: DateTime.now(),
          createdBy: _uid,
        ),
      );
      _toast(asAdmin ? 'Administrador criado.' : 'Utilizador criado.');
    } catch (e) {
      _toast('Erro ao criar: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editUser(AppUser user) async {
    final nameCtrl = TextEditingController(text: user.displayName);
    final emailCtrl = TextEditingController(text: user.email);
    final passCtrl = TextEditingController();
    var obscure = true;
    var role = user.role;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Editar utilizador'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email (login)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passCtrl,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          labelText: 'Nova palavra-passe (opcional)',
                          helperText: 'Deixa vazio para não alterar.',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscure ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setLocal(() => obscure = !obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Papel',
                          border: OutlineInputBorder(),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<AppUserRole>(
                            isExpanded: true,
                            value: role,
                            items: AppUserRole.values
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r.label),
                                  ),
                                )
                                .toList(),
                            onChanged: user.id == _uid
                                ? null
                                : (v) {
                                    if (v != null) setLocal(() => role = v);
                                  },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
            );
          },
        );
      },
    );

    final name = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text;
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    if (ok != true) return;
    if (email.isEmpty) {
      _toast('O email é obrigatório.', error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final note = await _adminUsers.updateUser(
        user: user,
        displayName: name,
        email: email,
        newPassword: pass.isEmpty ? null : pass,
        role: role,
      );
      _toast(
        note == null || note.isEmpty
            ? 'Utilizador atualizado.'
            : 'Utilizador atualizado. $note',
      );
    } catch (e) {
      _toast('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBlock(AppUser user) async {
    if (user.id == _uid) {
      _toast('Não podes bloquear a tua própria conta.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await _fs.setAppUserBlocked(user.id, !user.blocked);
      _toast(user.blocked ? 'Utilizador desbloqueado.' : 'Utilizador bloqueado.');
    } catch (e) {
      _toast('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setRole(AppUser user, AppUserRole role) async {
    if (user.id == _uid && role != AppUserRole.admin) {
      _toast('Não podes remover o teu próprio papel de admin.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await _fs.setAppUserRole(user.id, role);
      _toast(
        role == AppUserRole.admin
            ? 'Promovido a administrador.'
            : 'Passou a utilizador normal.',
      );
    } catch (e) {
      _toast('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteUser(AppUser user) async {
    if (user.id == _uid) {
      _toast('Não podes apagar a tua própria conta.', error: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar utilizador'),
        content: Text(
          'Remover «${user.displayName.isNotEmpty ? user.displayName : user.email}» '
          'da app? Deixa de conseguir entrar (a conta Auth pode continuar no Firebase).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _fs.softDeleteAppUser(user.id);
      _toast('Utilizador removido da app.');
    } catch (e) {
      _toast('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _fs.watchAppUser(_uid),
      builder: (context, meSnap) {
        final me = meSnap.data;
        final isAdmin = me?.isAdmin == true;

        return StreamBuilder<bool>(
          stream: _fs.watchHasAdminConfigured(),
          builder: (context, adminCfgSnap) {
            final hasAdmin = adminCfgSnap.data == true || isAdmin;

            if (!isAdmin && hasAdmin) {
              return const SizedBox.shrink();
            }

            return Card(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.admin_panel_settings_outlined,
                          color: Color(0xFF1A237E),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Administração',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A237E),
                            ),
                          ),
                        ),
                        if (_busy)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isAdmin
                          ? 'Cria, bloqueia ou remove utilizadores. '
                              '«Sincronizar» importa contas já usadas no Firestore '
                              '(Auth sozinha não lista emails no telemóvel/PC).'
                          : 'Ainda não há administrador. Torna-te admin para gerir contas.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!isAdmin)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _claimAdmin,
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text('Tornar-me administrador'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1A237E),
                          ),
                        ),
                      )
                    else ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _createUser(asAdmin: false),
                            icon: const Icon(Icons.person_add_outlined),
                            label: const Text('Novo utilizador'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1A237E),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _createUser(asAdmin: true),
                            icon: const Icon(Icons.shield_outlined),
                            label: const Text('Novo admin'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _syncUsers,
                            icon: const Icon(Icons.sync),
                            label: const Text('Sincronizar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<AppUser>>(
                        stream: _fs.watchAppUsers(),
                        builder: (context, listSnap) {
                          if (listSnap.hasError) {
                            return Text(
                              'Erro: ${listSnap.error}',
                              style: const TextStyle(color: Colors.red),
                            );
                          }
                          final users = listSnap.data ?? [];
                          if (users.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Sem utilizadores registados na app.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            );
                          }
                          return ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 320),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: users.length,
                              itemBuilder: (context, i) {
                                final u = users[i];
                                return _UserTile(
                                  user: u,
                                  isSelf: u.id == _uid,
                                  onEdit: () => _editUser(u),
                                  onBlock: () => _toggleBlock(u),
                                  onMakeAdmin: () =>
                                      _setRole(u, AppUserRole.admin),
                                  onMakeUser: () =>
                                      _setRole(u, AppUserRole.user),
                                  onDelete: () => _deleteUser(u),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.isSelf,
    required this.onEdit,
    required this.onBlock,
    required this.onMakeAdmin,
    required this.onMakeUser,
    required this.onDelete,
  });

  final AppUser user;
  final bool isSelf;
  final VoidCallback onEdit;
  final VoidCallback onBlock;
  final VoidCallback onMakeAdmin;
  final VoidCallback onMakeUser;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = user.displayName.trim().isNotEmpty
        ? user.displayName.trim()
        : user.email;
    final subtitle = [
      user.email,
      user.role.label,
      if (user.blocked) 'Bloqueado',
      if (isSelf) 'Tu',
    ].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: user.blocked
            ? Colors.red.shade100
            : const Color(0xFF1A237E).withValues(alpha: 0.12),
        child: Icon(
          user.role == AppUserRole.admin
              ? Icons.shield_outlined
              : Icons.person_outline,
          color: user.blocked ? Colors.red : const Color(0xFF1A237E),
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          switch (v) {
            case 'edit':
              onEdit();
            case 'block':
              onBlock();
            case 'admin':
              onMakeAdmin();
            case 'user':
              onMakeUser();
            case 'delete':
              onDelete();
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'edit',
            child: Text('Editar dados'),
          ),
          if (!isSelf)
            PopupMenuItem(
              value: 'block',
              child: Text(user.blocked ? 'Desbloquear' : 'Bloquear'),
            ),
          if (user.role != AppUserRole.admin)
            const PopupMenuItem(
              value: 'admin',
              child: Text('Tornar administrador'),
            ),
          if (user.role == AppUserRole.admin && !isSelf)
            const PopupMenuItem(
              value: 'user',
              child: Text('Remover admin'),
            ),
          if (!isSelf)
            const PopupMenuItem(
              value: 'delete',
              child: Text('Apagar da app'),
            ),
        ],
      ),
    );
  }
}
