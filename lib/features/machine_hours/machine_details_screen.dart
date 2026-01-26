import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:okoskert_internal/core/utils/services/project_service.dart';
import 'package:okoskert_internal/features/machine_hours/ui/add_working_hours_bottom_sheet.dart';

class MachineDetailsScreen extends StatefulWidget {
  final String machineId;
  const MachineDetailsScreen({super.key, required this.machineId});

  @override
  State<MachineDetailsScreen> createState() => _MachineDetailsScreenState();
}

class _MachineDetailsScreenState extends State<MachineDetailsScreen> {
  void _showAddWorkHoursModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => AddWorkHoursBottomSheet(machineId: widget.machineId),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}. ${date.month.toString().padLeft(2, '0')}. ${date.day.toString().padLeft(2, '0')}.';
  }

  String? _getProjectName(
    String? projectId,
    List<Map<String, dynamic>> projects,
  ) {
    if (projectId == null) return null;
    final project = projects.firstWhere(
      (p) => p['id'] == projectId,
      orElse: () => {},
    );
    return project['projectName'] as String? ?? 'Ismeretlen projekt';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Gép részletei",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future:
              FirebaseFirestore.instance
                  .collection('machines')
                  .doc(widget.machineId)
                  .get(),
          builder: (context, machineSnapshot) {
            if (machineSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (machineSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Hiba történt a gép adatainak betöltésekor: ${machineSnapshot.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final machineData = machineSnapshot.data?.data();
            if (machineData == null) {
              return const Center(
                child: Text(
                  'A gép nem található',
                  style: TextStyle(fontSize: 16),
                ),
              );
            }

            final machineName =
                machineData['name'] as String? ?? 'Ismeretlen gép';
            final tmkMaintenanceHours =
                machineData['tmkMaintenanceHours'] as num? ?? 0;
            final maintenances = [
              if (tmkMaintenanceHours > 0)
                {'name': 'TMK karbantartás', 'hours': tmkMaintenanceHours},
              ...(machineData['maintenances'] as List<dynamic>? ?? []),
            ];

            // Single StreamBuilder for workHoursLog - used for both header and list
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance
                      .collection('machines')
                      .doc(widget.machineId)
                      .collection('workHoursLog')
                      .orderBy('date', descending: true)
                      .snapshots(),
              builder: (context, workHoursSnapshot) {
                if (workHoursSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (workHoursSnapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Hiba történt az adatok betöltésekor: ${workHoursSnapshot.error}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final logDocs = workHoursSnapshot.data?.docs ?? [];

                // Calculate current hours from the maximum newHours value
                num currentHours = 0;
                if (logDocs.isNotEmpty) {
                  final allNewHours =
                      logDocs
                          .map((doc) {
                            final data = doc.data();
                            final newHours = data['newHours'];
                            if (newHours is num) {
                              return newHours;
                            }
                            return 0;
                          })
                          .where((hours) => hours > 0)
                          .toList();

                  if (allNewHours.isNotEmpty) {
                    currentHours = allNewHours.reduce((a, b) => a > b ? a : b);
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with current hours
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        spacing: 16,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Hero(
                            tag: widget.machineId,
                            child: const CircleAvatar(
                              radius: 32,
                              child: Icon(Icons.agriculture, size: 32),
                            ),
                          ),
                          Text(
                            machineName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            currentHours.toString(),
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Maintenances Card
                    if (maintenances.isNotEmpty)
                      Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                spacing: 8,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    child: Icon(LucideIcons.wrench, size: 16),
                                  ),
                                  Text(
                                    "Karbantartások",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...maintenances.map((m) {
                                final maintenance = m as Map<String, dynamic>;
                                final name = maintenance['name'] ?? 'Névtelen';
                                final hours = maintenance['hours'] ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                        child: Text(
                                          "$hours óra",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                    // Work hours log list
                    Card(
                      elevation: 1,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              spacing: 8,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  child: Icon(LucideIcons.clock, size: 16),
                                ),
                                Text(
                                  "Óraállás bejegyzések",
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            _buildWorkHoursList(logDocs),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWorkHoursModal,
        label: const Text("Óraállás rögzítése"),
        icon: const Icon(LucideIcons.clockPlus),
      ),
    );
  }

  Widget _buildWorkHoursList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> logDocs,
  ) {
    if (logDocs.isEmpty) {
      return const Center(
        child: Text(
          'Még nincsenek óraállás bejegyzések',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    // Collect all unique project IDs from logs
    final projectIds =
        logDocs
            .map((d) => d.data()['assignedProjectId'])
            .whereType<String>()
            .toSet()
            .toList();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ProjectService.getProjectNames(projectIds),
      builder: (context, projectFuture) {
        if (projectFuture.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final projects = projectFuture.data ?? [];

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...logDocs.asMap().entries.map((entry) {
              final index = entry.key;
              final doc = entry.value;
              final data = doc.data();
              final date = data['date'] as Timestamp?;
              final previousHours = data['previousHours'].toInt() as num? ?? 0;
              final newHours = data['newHours'].toInt() as num? ?? 0;
              final assignedProjectId = data['assignedProjectId'] as String?;
              final projectName = _getProjectName(assignedProjectId, projects);

              final dateText =
                  date != null
                      ? _formatDate(date.toDate())
                      : 'Ismeretlen dátum';
              final subtitle =
                  projectName != null
                      ? '$projectName - $previousHours-> $newHours  (${(newHours - previousHours)} óra)'
                      : '$previousHours -> $newHours  (${(newHours - previousHours)} óra)';

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      dateText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    subtitle: Text(subtitle),
                  ),
                  if (index < logDocs.length - 1) const Divider(height: 1),
                ],
              );
            }).toList(),
          ],
        );
      },
    );
  }
}
