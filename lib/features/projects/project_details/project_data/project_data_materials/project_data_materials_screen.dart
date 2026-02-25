import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:okoskert_internal/data/services/materials_services.dart';
import 'package:okoskert_internal/features/warehouse/add_material_screen.dart';
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
            return ListView.builder(
              itemCount: materials.length,
              itemBuilder: (context, index) {
                final material = materials[index].data();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: MaterialListTile(
                    name: material['name'],
                    quantity: material['quantity'],
                    unit: material['unit'],
                    price: material['price'],
                    projectName: material['projectName'],
                    onTap: () {
                      MaterialDetailsBottomSheet.show(
                        context,
                        materials[index],
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
