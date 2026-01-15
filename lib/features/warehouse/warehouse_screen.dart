import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:okoskert_internal/features/warehouse/add_material_screen.dart';
import 'package:okoskert_internal/features/warehouse/ui/material_details_bottom_sheet.dart';

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
                    padding: const EdgeInsets.all(8.0),
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

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(LucideIcons.package),
                          ),
                          title: Text(
                            name,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mennyiség: $quantity $unit'),
                              if (price != null)
                                Text(
                                  'Ár: ${_formatPrice(price.toDouble())} HUF',
                                ),
                              if (projectId != null &&
                                  projectsMap.containsKey(projectId))
                                Text(
                                  'Projekt: ${projectsMap[projectId]}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          isThreeLine: true,
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

  String _formatPrice(double price) {
    // Formázás 3 számjegyenkénti elválasztással szóközzel
    final priceInt = price.toInt();
    final priceStr = priceInt.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < priceStr.length; i++) {
      if (i > 0 && (priceStr.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(priceStr[i]);
    }

    return buffer.toString();
  }
}
