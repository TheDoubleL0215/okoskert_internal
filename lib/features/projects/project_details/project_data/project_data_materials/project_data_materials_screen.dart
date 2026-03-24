import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:okoskert_internal/data/services/materials_services.dart';
import 'package:okoskert_internal/features/warehouse/add_material_screen.dart';
import 'package:okoskert_internal/features/warehouse/material_group_by_day.dart';
import 'package:okoskert_internal/features/warehouse/ui/material_details_bottom_sheet.dart';
import 'package:okoskert_internal/features/warehouse/ui/material_list_tile.dart';

class ProjectDataMaterialsScreen extends StatefulWidget {
  final String projectId;
  const ProjectDataMaterialsScreen({super.key, required this.projectId});

  @override
  State<ProjectDataMaterialsScreen> createState() =>
      _ProjectDataMaterialsScreenState();
}

class _ProjectDataMaterialsScreenState
    extends State<ProjectDataMaterialsScreen> {
  final Object _fabHeroTag = Object();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: MaterialsServices.getMaterials(widget.projectId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Hiba történt az alapanyagok betöltésekor: ${snapshot.error}',
                ),
              );
            }
            final materials = snapshot.data ?? [];
            final projectsMap = <String, String>{};

            if (materials.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.package,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nincsenek alapanyagok ehhez a projekthez',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final grouped = groupMaterialsByDay(materials);
            final sortedDays =
                grouped.keys.toList()..sort((a, b) => b.compareTo(a));
            final rows = <Object>[
              for (final day in sortedDays) ...[day, ...grouped[day]!],
            ];

            return ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final item = rows[index];
                if (item is DateTime) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                    child: Text(
                      materialDaySectionTitle(item),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }
                final doc = item as QueryDocumentSnapshot<Map<String, dynamic>>;
                final data = doc.data();
                final name = data['name'] as String? ?? 'Névtelen alapanyag';
                final quantity = data['quantity'] as num? ?? 0.0;
                final unit = data['unit'] as String? ?? '';
                final price = data['price'] as num?;
                final projectName = data['projectName'] as String?;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: MaterialListTile(
                    name: name,
                    quantity: quantity,
                    unit: unit,
                    price: price,
                    projectName: projectName,
                    onTap: () {
                      MaterialDetailsBottomSheet.show(
                        context,
                        doc,
                        projectsMap,
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: _fabHeroTag,
        label: const Text('Alapanyag hozzáadása'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AddMaterialScreen(projectId: widget.projectId),
            ),
          );
        },
        icon: const Icon(LucideIcons.packagePlus),
      ),
    );
  }
}
