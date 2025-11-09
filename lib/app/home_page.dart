import 'package:flutter/material.dart';
import 'package:okoskert_internal/features/admin/AdminPage.dart';
import 'package:okoskert_internal/features/machine_hours/MachineHoursScreen.dart';
import 'package:okoskert_internal/features/projects/ProjectsCollectorScreen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentPageIndex = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          <Widget>[
            Projectscollectorscreen(),
            Scaffold(body: Center(child: Text("Naptár"))),
            MachineHoursScreen(),
            AdminPage(),
          ][currentPageIndex],

      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: 'Projektek',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Naptár',
          ),
          NavigationDestination(icon: Icon(Icons.av_timer), label: 'Üzemórák'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Admin'),
        ],
      ),
    );
  }
}
