import 'package:flutter/material.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:okoskert_internal/features/admin/AdminPage.dart';
import 'package:okoskert_internal/features/projects/ProjectsCollectorScreen.dart';
import 'package:okoskert_internal/features/calendar/CalendarScreen.dart';
import 'package:okoskert_internal/app/profile_page.dart';

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
                selectedIcon: Icon(Icons.home),
                icon: Icon(Icons.home_outlined),
                label: 'Projektek',
              ),
              const NavigationDestination(
                icon: Icon(Icons.calendar_month),
                label: 'Naptár',
              ),
              NavigationDestination(
                icon: Icon(isAdmin ? Icons.settings : Icons.person),
                label: isAdmin ? 'Admin' : 'Profil',
              ),
            ],
          ),
        );
      },
    );
  }
}
