import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:okoskert_internal/features/machine_hours/machine_hours_screen.dart';
import 'package:okoskert_internal/features/projects/create_project/create_project_screen.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/ProjectDataScreen.dart';
import 'package:okoskert_internal/features/projects/project_details/project_details_screen.dart';
import 'package:okoskert_internal/features/projects/ui/ProjectTile.dart';

class Projectscollectorscreen extends StatefulWidget {
  const Projectscollectorscreen({super.key});

  @override
  State<Projectscollectorscreen> createState() =>
      _ProjectscollectorscreenState();
}

enum SortOption { projectName, lastModified }

class _ProjectscollectorscreenState extends State<Projectscollectorscreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allProjects = [];
  final GlobalKey<ExpandableFabState> _expandableFabKey =
      GlobalKey<ExpandableFabState>();
  SortOption _selectedSortOption = SortOption.projectName;

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
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        body: SafeArea(
          minimum: EdgeInsets.all(8),
          child: Column(
            spacing: 8,
            children: [
              SearchAnchor.bar(
                textCapitalization: TextCapitalization.sentences,
                onClose: () {
                  // Adding a frame delay ensures the focus doesn't
                  // snap back to the search bar once the view is gone.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    FocusScope.of(context).unfocus();
                  });
                },
                barElevation: WidgetStateProperty.all(0),
                barBackgroundColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.secondaryContainer,
                ),
                barHintText: "Keresés projektek között",
                barLeading: const Icon(Icons.search),

                suggestionsBuilder: (context, controller) {
                  final query = controller.text.toLowerCase();

                  if (query.isEmpty) {
                    return const [];
                  }
                  final results =
                      _allProjects.where((doc) {
                        final data = doc.data();
                        final name =
                            (data['projectName'] ?? '')
                                .toString()
                                .toLowerCase();
                        final customerName =
                            (data['customerName'] ?? '')
                                .toString()
                                .toLowerCase();
                        final projectLocation =
                            (data['projectLocation'] ?? '')
                                .toString()
                                .toLowerCase();
                        return name.contains(query) ||
                            customerName.contains(query) ||
                            projectLocation.contains(query);
                      }).toList();

                  return results.map((doc) {
                    final data = doc.data();
                    final projectId = doc.id;
                    final projectName =
                        data['projectName'] ?? 'Névtelen projekt';

                    return ListTile(
                      title: Text(projectName),
                      leading: CircleAvatar(
                        child: const Icon(Icons.construction_rounded),
                      ),
                      trailing: InkWell(
                        onTap: () {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            FocusScope.of(context).unfocus();
                          });
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => ProjectDetailsScreen(
                                    projectId: projectId,
                                    projectName: projectName,
                                  ),
                            ),
                          );
                        },
                        child: Icon(LucideIcons.info),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ProjectDataScreen(
                                  projectId: projectId,
                                  projectName: projectName,
                                ),
                          ),
                        );
                      },
                    );
                  }).toList();
                },
              ),

              // Rendezési chip-ek
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('Név szerint'),
                    selected: _selectedSortOption == SortOption.projectName,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedSortOption = SortOption.projectName;
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: Text('Utolsó módosítás'),
                    selected: _selectedSortOption == SortOption.lastModified,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedSortOption = SortOption.lastModified;
                        });
                      }
                    },
                  ),
                ],
              ),

              Expanded(
                child: Column(
                  children: [
                    TabBar(
                      dividerColor: Colors.transparent,
                      controller: _tabController,
                      tabs: [
                        Tab(
                          text: "Folyamatban",
                          icon: Icon(LucideIcons.hammer),
                        ),
                        Tab(text: "Kész", icon: Icon(LucideIcons.circleCheck)),
                        Tab(
                          text: "Karbantartás",
                          icon: Icon(LucideIcons.wrench),
                        ),
                      ],
                    ),
                    Expanded(
                      child: FutureBuilder<String?>(
                        future: UserService.getTeamId(),
                        builder: (context, teamIdSnapshot) {
                          if (teamIdSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final teamId = teamIdSnapshot.data;
                          if (teamId == null || teamId.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'Hiba: nem található teamId',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }

                          return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>
                          >(
                            stream:
                                FirebaseFirestore.instance
                                    .collection('projects')
                                    .where('teamId', isEqualTo: teamId)
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
                                        color:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }

                              final allDocs = snapshot.data?.docs ?? [];
                              _allProjects = allDocs;

                              // Rendezés alkalmazása
                              final sortedDocs = List<
                                QueryDocumentSnapshot<Map<String, dynamic>>
                              >.from(allDocs);
                              sortedDocs.sort((a, b) {
                                final dataA = a.data();
                                final dataB = b.data();

                                if (_selectedSortOption ==
                                    SortOption.projectName) {
                                  final nameA =
                                      (dataA['projectName'] ?? '')
                                          .toString()
                                          .toLowerCase();
                                  final nameB =
                                      (dataB['projectName'] ?? '')
                                          .toString()
                                          .toLowerCase();
                                  return nameA.compareTo(nameB);
                                } else {
                                  // Utolsó módosítás szerint
                                  final updatedAtA =
                                      dataA['updatedAt'] as Timestamp?;
                                  final updatedAtB =
                                      dataB['updatedAt'] as Timestamp?;

                                  if (updatedAtA == null &&
                                      updatedAtB == null) {
                                    return 0;
                                  }
                                  if (updatedAtA == null) return 1;
                                  if (updatedAtB == null) return -1;

                                  // Újabb dátum előrébb (csökkenő sorrend)
                                  return updatedAtB.compareTo(updatedAtA);
                                }
                              });

                              return TabBarView(
                                controller: _tabController,
                                children: [
                                  buildProjectList(sortedDocs, "ongoing"),
                                  buildProjectList(sortedDocs, "done"),
                                  buildProjectList(sortedDocs, "maintenance"),
                                ],
                              );
                            },
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
        floatingActionButton: FutureBuilder<int?>(
          future: UserService.getRole(),
          builder: (context, roleSnapshot) {
            final role = roleSnapshot.data;

            return ExpandableFab(
              key: _expandableFabKey,
              type: ExpandableFabType.up,
              childrenAnimation: ExpandableFabAnimation.none,
              distance: 70,
              overlayStyle: ExpandableFabOverlayStyle(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerLow.withValues(alpha: 0.7),
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
                if (role == 1)
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
            );
          },
        ),
      ),
    );
  }
}
