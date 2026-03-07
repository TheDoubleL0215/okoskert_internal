import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:okoskert_internal/features/admin/admin_screen.dart';
import 'package:okoskert_internal/features/projects/projects_collector_screen.dart';
import 'package:okoskert_internal/features/calendar/calendar_screen.dart';
import 'package:okoskert_internal/app/profile_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:okoskert_internal/features/web_layout/web_main_layout.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: UserService.getRole(),
      builder: (context, roleSnapshot) {
        final role = roleSnapshot.data;
        final isAdmin = role == 1;

        if (kIsWeb) {
          return const WebMainLayout();
        }

        final pages = <Widget>[
          const Projectscollectorscreen(),
          const CalendarScreen(),
          isAdmin ? const AdminPage() : const ProfilePage(),
        ];

        return Scaffold(
          body: pages[currentPageIndex],
          bottomNavigationBar: NavigationBar(
            onDestinationSelected: (int index) {
              setState(() {
                currentPageIndex = index;
              });
            },
            selectedIndex: currentPageIndex,
            destinations: <Widget>[
              const NavigationDestination(
                icon: Icon(LucideIcons.clipboardList),
                label: 'Projektek',
              ),
              const NavigationDestination(
                icon: Icon(LucideIcons.calendarDays),
                label: 'Naptár',
              ),
              NavigationDestination(
                icon: Icon(isAdmin ? LucideIcons.cog : LucideIcons.user),
                label: isAdmin ? 'Admin' : 'Profil',
              ),
            ],
          ),
        );
      },
    );
  }
}
