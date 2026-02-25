import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:okoskert_internal/features/warehouse/add_material_screen.dart';
import 'package:okoskert_internal/features/warehouse/ui/material_details_bottom_sheet.dart';
import 'package:okoskert_internal/features/warehouse/ui/material_list_tile.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raktár')),
      body: FutureBuilder<String?>(
        future: UserService.getTeamId(),
        builder: (context, teamIdSnapshot) {
          if (teamIdSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final teamId = teamIdSnapshot.data;
          if (teamId == null || teamId.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Hiba: nem található teamId',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance
                    .collection('projects')
                    .where('teamId', isEqualTo: teamId)
                    .snapshots(),
            builder: (context, projectsSnapshot) {
              // Projektek Map-ben tárolása (ID -> név)
              final projectsMap = <String, String>{};
              if (projectsSnapshot.hasData) {
                for (final doc in projectsSnapshot.data!.docs) {
                  final data = doc.data();
                  projectsMap[doc.id] =
                      data['projectName'] as String? ?? 'Névtelen projekt';
                }
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    FirebaseFirestore.instance
                        .collection('materials')
                        .where('teamId', isEqualTo: teamId)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    debugPrint(
                      'Hiba történt az alapanyagok betöltésekor: ${snapshot.error}',
                    );
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Hiba történt az alapanyagok betöltésekor: ${snapshot.error}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final materials = snapshot.data?.docs ?? [];

                  if (materials.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.package,
                            size: 64,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nincsenek alapanyagok',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Kattints az "Alapanyag hozzáadása" gombra a kezdéshez',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    itemCount: materials.length,
                    itemBuilder: (context, index) {
                      final material = materials[index];
                      final data = material.data();
                      final name =
                          data['name'] as String? ?? 'Névtelen alapanyag';
                      final quantity = data['quantity'] as num? ?? 0.0;
                      final unit = data['unit'] as String? ?? '';
                      final price = data['price'] as num?;
                      final projectId = data['projectId'] as String?;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: MaterialListTile(
                          name: name,
                          quantity: quantity,
                          unit: unit,
                          price: price,
                          projectName:
                              projectId != null ? projectsMap[projectId] : null,
                          onTap: () {
                            MaterialDetailsBottomSheet.show(
                              context,
                              material,
                              projectsMap,
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        label: const Text('Alapanyag hozzáadása'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddMaterialScreen()),
          );
        },
        icon: Icon(LucideIcons.packagePlus),
      ),
    );
  }
}
