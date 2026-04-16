import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:okoskert_internal/app/session_provider.dart';
import 'package:okoskert_internal/app/workspace_provider.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:okoskert_internal/data/services/get_worklog_summary.dart';
import 'package:okoskert_internal/features/projects/create_project/create_project_screen.dart';
import 'package:okoskert_internal/features/projects/project_details/contact_details_section.dart';
import 'package:okoskert_internal/features/projects/project_details/description_accordion.dart';
import 'package:okoskert_internal/features/projects/project_details/ui/ProjectStatusChip.dart';
import 'package:okoskert_internal/features/worklog/models/wage_type_option.dart';
import 'package:okoskert_internal/features/worklog/ui/wage_type_selection_bottom_sheet.dart';
import 'package:okoskert_internal/features/warehouse/ui/material_details_bottom_sheet.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ProjectDetailsScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final role = session.role;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName),
        actions: [
          if (role == 1)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                child: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => CreateProjectScreen(
                              projectId: widget.projectId,
                            ),
                      ),
                    );
                    // No need to refresh manually — StreamBuilder handles it.
                  },
                ),
              ),
            ),
        ],
      ),

      // 🔥 STREAMBUILDER → Live project detail updates
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection("projects")
                .doc(widget.projectId)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Hiba: ${snapshot.error}"));
          }

          final doc = snapshot.data!;
          final projectData = doc.data() as Map<String, dynamic>?;

          if (projectData == null) {
            return const Center(child: Text("A projekt nem található"));
          }

          return ProjectDetailsContent(
            projectId: widget.projectId,
            projectName: widget.projectName,
            projectData: projectData,
          );
        },
      ),
    );
  }
}

class ProjectDetailsContent extends StatelessWidget {
  final String projectId;
  final String projectName;
  final Map<String, dynamic> projectData;

  const ProjectDetailsContent({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.projectData,
  });

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final role = session.role;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(
                      projectData['customerName'] ?? 'Nincs megadva',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),

                  padding16(
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(
                          projectData['projectType'].length,
                          (index) => Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Chip(
                              avatar: const Icon(Icons.tag),
                              label: Text(projectData['projectType'][index]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  padding16(
                    ProjectStatusChip(
                      isEditable: role != 3,
                      context: context,
                      projectId: projectId,
                      currentStatus:
                          projectData['projectStatus'] as String? ?? 'ongoing',
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (projectData['customerPhone'] != null ||
                      projectData['customerEmail'] != null ||
                      projectData['projectLocation'] != null)
                    padding16(
                      ContactDetailsSection(
                        customerPhone: projectData['customerPhone'],
                        customerEmail: projectData['customerEmail'],
                        projectLocation: projectData['projectLocation'],
                      ),
                    ),

                  if (projectData['projectDescription'] != null &&
                      projectData['projectDescription']
                          .toString()
                          .trim()
                          .isNotEmpty)
                    DescriptionAccordion(
                      projectDescription: projectData['projectDescription'],
                    ),

                  const SizedBox(height: 24),

                  padding16(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alapanyagok',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        MaterialsSection(projectId: projectId),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  padding16(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Munkaórák összesítése',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        WorklogSummarySection(projectId: projectId),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom buttons
          if (role != 3) ...[
            padding16(
              Column(
                children: [
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _beginProjectExport(context, projectId),
                    icon: const Icon(Icons.download),
                    label: const Text(
                      'Projekt adatainak exportálása',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const String _projectExportBaseUrl =
    'https://us-central1-okoskert-dev.cloudfunctions.net/projectExport';

Future<List<WageTypeOption>> _fetchWageTypesForExport(
  DocumentReference<Map<String, dynamic>> workspaceRef,
) async {
  final wageSnap =
      await workspaceRef
          .collection('wageTypes')
          .orderBy('createdAt', descending: false)
          .get();
  return wageSnap.docs.map((doc) {
    final data = doc.data();
    final name = (data['name'] ?? '').toString().trim();
    final dv = data['defaultValue'];
    final defaultValue =
        dv is int
            ? dv
            : dv is num
            ? dv.toInt()
            : int.tryParse(dv?.toString() ?? '') ?? 0;
    return WageTypeOption(
      id: doc.id,
      name: name.isEmpty ? 'Névtelen' : name,
      defaultValue: defaultValue,
    );
  }).toList();
}

Future<void> _beginProjectExport(BuildContext context, String projectId) async {
  if (!context.mounted) return;
  final workspace = context.read<WorkspaceProvider>();
  if (workspace.isLoading && workspace.workspaceRef == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('A munkatér betöltése folyamatban...')),
    );
    return;
  }
  final ref = workspace.workspaceRef;
  if (ref == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          workspace.error != null && workspace.error!.isNotEmpty
              ? 'Munkatér: ${workspace.error}'
              : 'Nem található munkatér a bértípusok betöltéséhez.',
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
    return;
  }

  try {
    final wageTypes = await _fetchWageTypesForExport(ref);
    if (!context.mounted) return;
    if (wageTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nincs elérhető bértípus az exportáláshoz.'),
        ),
      );
      return;
    }
    final selected = await showWageTypeSelectionBottomSheet(
      context: context,
      wageTypes: wageTypes,
      confirmButtonLabel: 'Exportálás',
    );
    if (!context.mounted || selected == null) return;
    await _exportProjectData(context, projectId, wageType: selected.id);
  } catch (e, st) {
    debugPrint('Wage types load error: $e $st');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bértípusok betöltése sikertelen: $e'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

Future<void> _exportProjectData(
  BuildContext context,
  String projectId, {
  required String wageType,
}) async {
  if (!context.mounted) return;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder:
        (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Exportálás...'),
                ],
              ),
            ),
          ),
        ),
  );

  try {
    final uri = Uri.parse(
      _projectExportBaseUrl,
    ).replace(queryParameters: {'projectId': projectId, 'wageType': wageType});
    final response = await http.get(uri);

    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss loading dialog

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exportálási hiba: ${response.statusCode}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>?;
    final fileName = body?['fileName'] as String?;
    final storagePath = body?['storagePath'] as String?;

    if (fileName == null || storagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Érvénytelen válasz a szervertől')),
      );
      return;
    }

    final ref = FirebaseStorage.instance.ref(storagePath);
    const maxSize = 50 * 1024 * 1024; // 50 MB
    final data = await ref.getData(maxSize);
    if (data == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A fájl letöltése sikertelen')),
      );
      return;
    }

    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(data);

    if (!context.mounted) return;
    final result = await OpenFilex.open(file.path);
    if (!context.mounted) return;
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fájl megnyitása: ${result.message}')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Exportálás kész')));
    }
  } catch (e, st) {
    debugPrint('Export error: $e $st');
    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss loading if still open
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hiba: $e'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

// --- Small util widget ---
Widget padding16(Widget child) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child);

// --- Materials section ---
class MaterialsSection extends StatelessWidget {
  final String projectId;

  const MaterialsSection({super.key, required this.projectId});

  String _formatPrice(double price) {
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: UserService.getTeamId(),
      builder: (context, teamIdSnapshot) {
        if (teamIdSnapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final teamId = teamIdSnapshot.data;
        if (teamId == null || teamId.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Hiba: nem található teamId'),
          );
        }

        // Projektek betöltése a projectsMap-hez
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
                      .where('projectId', isEqualTo: projectId)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  debugPrint(
                    'Hiba történt az alapanyagok betöltésekor: ${snapshot.error}',
                  );
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Hiba történt az alapanyagok betöltésekor: ${snapshot.error}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  );
                }

                final materials = snapshot.data?.docs ?? [];

                if (materials.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Még nincsenek alapanyagok hozzárendelve ehhez a projekthez',
                    ),
                  );
                }

                return Column(
                  children:
                      materials.map((material) {
                        final data = material.data();
                        final name =
                            data['name'] as String? ?? 'Névtelen alapanyag';
                        final quantity = data['quantity'] as num? ?? 0.0;
                        final unit = data['unit'] as String? ?? '';
                        final price = data['price'] as num?;
                        final unitPrice = data['unitPrice'] as num?;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Mennyiség: $quantity $unit'),
                                if (unitPrice != null)
                                  Text(
                                    'Egységár: ${_formatPrice(unitPrice.toDouble())} HUF/$unit',
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
                            trailing:
                                price != null
                                    ? Text(
                                      '${_formatPrice(price.toDouble())} HUF',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                    )
                                    : null,
                            isThreeLine: unitPrice != null,
                            onTap: () {
                              MaterialDetailsBottomSheet.show(
                                context,
                                material,
                                projectsMap,
                              );
                            },
                          ),
                        );
                      }).toList(),
                );
              },
            );
          },
        );
      },
    );
  }
}

class WorklogSummarySection extends StatelessWidget {
  final String projectId;

  const WorklogSummarySection({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceProvider>();
    if (workspace.isLoading && workspace.workspaceRef == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final ref = workspace.workspaceRef;
    if (ref == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          workspace.error != null && workspace.error!.isNotEmpty
              ? 'Munkatér: ${workspace.error}'
              : 'Nem található munkatér a munkanapló összesítéshez.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    return FutureBuilder<List<WorklogSummary>>(
      future: WorklogService.getWorklogSummaryByEmployee(
        workspaceRef: ref,
        projectId: projectId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Munkanapló összesítés hiba: ${snapshot.error}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }

        final summaries = snapshot.data ?? [];
        if (summaries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Még nincsenek munkanapló bejegyzések ehhez a projekthez',
            ),
          );
        }

        return Column(
          children:
              summaries.map((summary) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(summary.employeeName),
                    subtitle: Text('${summary.entryCount} bejegyzés'),
                    trailing: Text(
                      _formatDuration(summary.totalDuration),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    if (h > 0 && m > 0) return '${h}ó ${m}p';
    if (h > 0) return '${h}ó';
    return '${m}p';
  }
}
