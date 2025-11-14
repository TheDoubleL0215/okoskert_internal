import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:okoskert_internal/features/machine_hours/MachineHoursScreen.dart';
import 'package:okoskert_internal/features/projects/create_project/CreateProjectScreen.dart';
import 'package:okoskert_internal/features/projects/ui/ProjectTile.dart';

class Projectscollectorscreen extends StatefulWidget {
  const Projectscollectorscreen({super.key});

  @override
  State<Projectscollectorscreen> createState() =>
      _ProjectscollectorscreenState();
}

class _ProjectscollectorscreenState extends State<Projectscollectorscreen>
    with SingleTickerProviderStateMixin {
  int selectedFilterIndex = 0;
  late TabController _tabController;
  final GlobalKey<ExpandableFabState> _expandableFabKey = GlobalKey<ExpandableFabState>();


  final List<String> filterOptions = [
    "Betűrend",
    "Állapot",
    "Utoljára frissítve",
    "Munka típusa",
    "Prioritás",
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        minimum: EdgeInsets.all(8),
        child: Column(
          spacing: 16,
          children: [
            SearchBar(
              backgroundColor: WidgetStateProperty.all(
                Theme.of(context).colorScheme.secondaryContainer,
              ),
              padding: WidgetStateProperty.all(
                EdgeInsets.symmetric(horizontal: 16),
              ),
              leading: Icon(Icons.search),
              hintText: "Keresés",
              elevation: WidgetStateProperty.all(0),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 8,
                children:
                    filterOptions.asMap().entries.map((entry) {
                      int index = entry.key;
                      String option = entry.value;
                      return ChoiceChip(
                        label: Text(option),
                        selected: selectedFilterIndex == index,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              selectedFilterIndex = index;
                            });
                          }
                        },
                      );
                    }).toList(),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: "Folyamatban lévő projektek"),
                      Tab(text: "Kész projektek"),
                      Tab(text: "Karbantartás"),
                    ],
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('projects')
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Hiba történt a projektek betöltésekor: ${snapshot.error}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        final allDocs = snapshot.data?.docs ?? [];

                        return TabBarView(
                          controller: _tabController,
                          children: [
                            buildProjectList(allDocs, "ongoing"),
                            buildProjectList(allDocs, "done"),
                            buildProjectList(allDocs, "maintenance"),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: ExpandableFab.location,
      floatingActionButton:ExpandableFab(
          key: _expandableFabKey,
          type: ExpandableFabType.up,
          childrenAnimation: ExpandableFabAnimation.none,
          distance: 70,
          overlayStyle: ExpandableFabOverlayStyle(
            color: Colors.white.withValues(alpha: 0.7),
          ),
          children: [
            Row(
              children: [
                FloatingActionButton.extended(
                  label: Text('Munkagépek kezelése'),
                  heroTag: null,
                  icon: Icon(Icons.av_timer),
                  onPressed: () {
                    _expandableFabKey.currentState?.close();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MachineHoursScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            Row(
              children: [
                FloatingActionButton.extended(
                  label: Text('Új projekt létrehozása'),
                  heroTag: null,
                  onPressed: () {
                    _expandableFabKey.currentState?.close();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateProjectScreen(),
                      ),
                    );
                  },
                  icon: Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
    );
  }
}
