import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/profile_screen.dart';
import 'ide_agenda/ide_agenda_screen.dart';
import 'projects/projects_screen.dart';
import 'tree/tree_tab_screen.dart';
import '../services/auth_service.dart';
import '../utils/app_update_prompt.dart';
import '../utils/user_display.dart';
import '../widgets/ide_agenda_projects_link_host.dart';

/// Shell principal: mesmas secções (Projetos, Perfil) em todos os sistemas.
/// Em ecrã largo (ex.: Windows) mostra barra lateral; no telemóvel usa abas no AppBar.
/// Deslize entre abas igual ao Android (`BouncingScrollPhysics`).
class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  /// Largura mínima para usar barra lateral em vez de TabBar no AppBar.
  static const double railBreakpoint = 840;

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
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      checkAndPromptAppUpdate(context);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static const _tabPhysics = BouncingScrollPhysics();

  Widget _tabPages() {
    return TabBarView(
      controller: _tabController,
      physics: _tabPhysics,
      children: const [
        ProjectsScreen(),
        TreeTabScreen(),
        IdeAgendaScreen(),
        ProfileScreen(embedded: true),
      ],
    );
  }

  PreferredSizeWidget? _tabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      indicatorColor: Colors.white,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      tabs: const [
        Tab(icon: Icon(Icons.folder_outlined), text: 'Projetos'),
        Tab(icon: Icon(Icons.account_tree_outlined), text: 'Árvore'),
        Tab(icon: Icon(Icons.desktop_windows_outlined), text: 'Agenda IDE'),
        Tab(icon: Icon(Icons.person_outline), text: 'Perfil'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, userSnapshot) {
        final user = userSnapshot.data ?? FirebaseAuth.instance.currentUser;
        final profileLine = firebaseProfileSubtitle(user);
        final screenWidth = MediaQuery.sizeOf(context).width;
        final wide = screenWidth >= HomeShellScreen.railBreakpoint;
        final extendedRail = screenWidth >= 1100;

        return IdeAgendaProjectsLinkHost(
          child: Scaffold(
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
            bottom: wide ? null : _tabBar(),
          ),
          body: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NavigationRail(
                      extended: extendedRail,
                      selectedIndex: _tabController.index,
                      onDestinationSelected: (i) => _tabController.animateTo(i),
                      backgroundColor: const Color(0xFFE8EAF6),
                      selectedIconTheme: const IconThemeData(color: Color(0xFF1A237E)),
                      selectedLabelTextStyle: const TextStyle(
                        color: Color(0xFF1A237E),
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedIconTheme: IconThemeData(color: Colors.grey[700]),
                      unselectedLabelTextStyle: TextStyle(color: Colors.grey[700]),
                      // Com extended=true o Flutter exige labelType none (senão assertion).
                      labelType: extendedRail
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.folder_outlined),
                          selectedIcon: Icon(Icons.folder),
                          label: Text('Projetos'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.account_tree_outlined),
                          selectedIcon: Icon(Icons.account_tree),
                          label: Text('Árvore'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.desktop_windows_outlined),
                          selectedIcon: Icon(Icons.desktop_windows),
                          label: Text('Agenda IDE'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.person_outline),
                          selectedIcon: Icon(Icons.person),
                          label: Text('Perfil'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: _tabPages()),
                  ],
                )
              : _tabPages(),
        ),
        );
      },
    );
  }
}
