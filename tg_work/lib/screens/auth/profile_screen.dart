import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../utils/user_display.dart';
import '../../widgets/profile_billing_section.dart';

/// Ver e alterar o nome no perfil Firebase. O email é mostrado; alterar email implica fluxos extra no Firebase.
/// Com [embedded] true (ex.: aba no `HomeShellScreen`), não mostra AppBar próprio.
class ProfileScreen extends StatefulWidget {
  final bool embedded;

  const ProfileScreen({super.key, this.embedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  final _nameController = TextEditingController();
  bool _loading = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _syncFromUser();
  }

  void _syncFromUser() {
    final u = FirebaseAuth.instance.currentUser;
    _nameController.text = u?.displayName?.trim() ?? '';
    _dirty = false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduz o teu nome no perfil.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.updateProfileDisplayName(name);
      if (mounted) {
        setState(() {
          _loading = false;
          _dirty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';

    final scroll = SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF1A237E).withValues(alpha: 0.15),
                child: const Icon(Icons.person, size: 44, color: Color(0xFF1A237E)),
              ),
              const SizedBox(height: 20),
              Text(
                firebaseUserDisplayLabel(user),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 8),
                SelectableText(
                  email,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
              const SizedBox(height: 28),
              const Text(
                'Nome no perfil',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'O teu nome (aparece nas auditorias)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 12),
              Text(
                'Este nome é usado quando crias ou alteras projetos, temas e desenvolvimentos. '
                'Se o deixares vazio ao gravar, usamos o email.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              Text(
                'Email',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                child: Text(
                  email.isEmpty ? '—' : email,
                  style: TextStyle(color: email.isEmpty ? Colors.grey : null),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Para mudar o email é preciso um fluxo de verificação no Firebase; por agora contacta o administrador ou usa o email da conta atual.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading || !_dirty ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Guardar nome'),
                ),
              ),
              const SizedBox(height: 28),
              const ProfileBillingSection(),
            ],
          ),
        ),
    );

    if (widget.embedded) {
      return scroll;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: scroll,
    );
  }
}
