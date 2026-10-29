import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/profile_screen.dart';
import 'ide_agenda/ide_agenda_screen.dart';
import 'projects/projects_screen.dart';
import 'settings/settings_screen.dart';
import 'tree/tree_tab_screen.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/app_update_prompt.dart';
import '../utils/user_display.dart';
import '../widgets/ide_agenda_projects_link_host.dart';

class _ShellDest {
  const _ShellDest({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}

/// Shell principal: Projetos, Árvore, Agenda, Definições, Perfil.
/// Em ecrã largo (ex.: Windows) mostra barra lateral; no telemóvel usa abas no AppBar.
class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  static const double railBreakpoint = 840;

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _fs = FirestoreService();
  TabController? _tabController;
  String _tabsKey = '';

  static const _tabPhysics = BouncingScrollPhysics();

  List<_ShellDest> _destinationsFor(AppUser? me) {
    final all = <_ShellDest>[
      const _ShellDest(
        id: 'projects',
        label: 'Projetos',
        icon: Icons.folder_outlined,
        selectedIcon: Icons.folder,
        page: ProjectsScreen(),
      ),
      const _ShellDest(
        id: 'tree',
        label: 'Árvore',
        icon: Icons.account_tree_outlined,
        selectedIcon: Icons.account_tree,
        page: TreeTabScreen(),
      ),
      const _ShellDest(
        id: 'agenda',
        label: 'Agenda IDE',
        icon: Icons.desktop_windows_outlined,
        selectedIcon: Icons.desktop_windows,
        page: IdeAgendaScreen(),
      ),
      const _ShellDest(
        id: 'settings',
        label: 'Definições',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        page: SettingsScreen(),
      ),
      const _ShellDest(
        id: 'profile',
        label: 'Perfil',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        page: ProfileScreen(embedded: true),
      ),
    ];

    // Sem perfil ainda: só Perfil + Definições (bootstrap admin / a carregar).
    // Assim áreas bloqueadas nunca aparecem na APK / PC do utilizador.
    if (me == null) {
      return all
          .where((d) => d.id == 'profile' || d.id == 'settings')
          .toList();
    }
    if (me.isAdmin) return all;

    return all.where((d) {
      switch (d.id) {
        case 'projects':
          return me.canOpenProjectsTab();
        case 'tree':
          return me.canOpenTreeTab();
        case 'agenda':
          return me.canOpenIdeAgendaTab();
        case 'settings':
          return me.canOpenSettingsTab();
        case 'profile':
          return true;
        default:
          return false;
      }
    }).toList();
  }

  void _ensureController(List<_ShellDest> dests) {
    final key = dests.map((d) => d.id).join('|');
    if (_tabController != null && _tabsKey == key) return;
    final oldIndex = _tabController?.index ?? 0;
    _tabController?.dispose();
    _tabsKey = key;
    _tabController = TabController(
      length: dests.length,
      vsync: this,
      initialIndex: dests.isEmpty ? 0 : oldIndex.clamp(0, dests.length - 1),
    );
    _tabController!.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      checkAndPromptAppUpdate(context);
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, userSnapshot) {
        final user = userSnapshot.data ?? FirebaseAuth.instance.currentUser;
        final uid = user?.uid ?? '';
        final profileLine = firebaseProfileSubtitle(user);
        final screenWidth = MediaQuery.sizeOf(context).width;
        final wide = screenWidth >= HomeShellScreen.railBreakpoint;
        final extendedRail = screenWidth >= 1100;

        return StreamBuilder<AppUser?>(
          stream: _fs.watchAppUser(uid),
          builder: (context, meSnap) {
            final me = meSnap.data;
            final dests = _destinationsFor(me);
            _ensureController(dests);
            final tc = _tabController!;

            return IdeAgendaProjectsLinkHost(
              child: Scaffold(
                appBar: AppBar(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'TG Work',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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
                  bottom: wide
                      ? null
                      : TabBar(
                          controller: tc,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          indicatorColor: Colors.white,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white70,
                          tabs: [
                            for (final d in dests)
                              Tab(icon: Icon(d.icon), text: d.label),
                          ],
                        ),
                ),
                body: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          NavigationRail(
                            extended: extendedRail,
                            selectedIndex: tc.index.clamp(0, dests.length - 1),
                            onDestinationSelected: (i) => tc.animateTo(i),
                            backgroundColor: const Color(0xFFE8EAF6),
                            selectedIconTheme: const IconThemeData(
                              color: Color(0xFF1A237E),
                            ),
                            selectedLabelTextStyle: const TextStyle(
                              color: Color(0xFF1A237E),
                              fontWeight: FontWeight.w600,
                            ),
                            unselectedIconTheme:
                                IconThemeData(color: Colors.grey[700]),
                            unselectedLabelTextStyle:
                                TextStyle(color: Colors.grey[700]),
                            labelType: extendedRail
                                ? NavigationRailLabelType.none
                                : NavigationRailLabelType.all,
                            destinations: [
                              for (final d in dests)
                                NavigationRailDestination(
                                  icon: Icon(d.icon),
                                  selectedIcon: Icon(d.selectedIcon),
                                  label: Text(d.label),
                                ),
                            ],
                          ),
                          const VerticalDivider(width: 1, thickness: 1),
                          Expanded(
                            child: TabBarView(
                              controller: tc,
                              physics: _tabPhysics,
                              children: [for (final d in dests) d.page],
                            ),
                          ),
                        ],
                      )
                    : TabBarView(
                        controller: tc,
                        physics: _tabPhysics,
                        children: [for (final d in dests) d.page],
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
