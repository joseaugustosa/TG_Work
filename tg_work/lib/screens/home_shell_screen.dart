import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/profile_screen.dart';
import 'projects/projects_screen.dart';
import '../services/auth_service.dart';
import '../utils/user_display.dart';

/// Shell principal com abas — funciona bem em Windows (navegação clara) e no telemóvel.
class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, userSnapshot) {
        final user = userSnapshot.data ?? FirebaseAuth.instance.currentUser;
        final profileLine = firebaseProfileSubtitle(user);

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('TG Work', style: TextStyle(fontWeight: FontWeight.bold)),
                if (profileLine.isNotEmpty)
                  Text(
                    profileLine,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Sair',
                  onPressed: () async => await _authService.signOut(),
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(icon: Icon(Icons.folder_outlined), text: 'Projetos'),
                Tab(icon: Icon(Icons.person_outline), text: 'Perfil'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            // No Windows/macOS/Linux: evita gesto horizontal que atrapalha com rato;
            // no Android/iOS mantém swipe entre abas.
            physics: Theme.of(context).platform == TargetPlatform.android ||
                    Theme.of(context).platform == TargetPlatform.iOS
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            children: const [
              ProjectsScreen(),
              ProfileScreen(embedded: true),
            ],
          ),
        );
      },
    );
  }
}
