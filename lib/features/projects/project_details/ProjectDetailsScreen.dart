import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/data/services/get_project_by_id.dart';
import 'package:okoskert_internal/data/services/get_worklog_summary.dart';
import 'package:okoskert_internal/features/projects/project_details/ProjectDetailsContactDetails.dart';
import 'package:okoskert_internal/features/projects/project_details/ProjectDetailsDescriptionAccordion.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/ProjectDataScreen.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.projectName,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: ProjectService.getProjectById(widget.projectId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Hiba történt a projekt betöltésekor: ${snapshot.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final projectData = snapshot.data;
          if (projectData == null) {
            return const Center(
              child: Text(
                'A projekt nem található',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: CircleAvatar(child: Icon(Icons.person)),
                        title: Text(
                          projectData['customerName'] ?? 'Nincs megadva',
                          style: Theme.of(
                            context,
                          ).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: Theme.of(context).colorScheme.primary,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _buildStatusChip(
                          context,
                          projectData['projectStatus'] as String? ?? 'ongoing',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (projectData['customerPhone'] != null ||
                          projectData['customerEmail'] != null ||
                          projectData['projectLocation'] != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: ProjectDetailsContactDetails(
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
                        ProjectDetailsDescriptionAccordion(
                          projectDescription: projectData['projectDescription'],
                        ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Munkaórák összesítése',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            FutureBuilder<List<WorklogSummary>>(
                              future:
                                  WorklogService.getWorklogSummaryByEmployee(
                                    widget.projectId,
                                  ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                if (snapshot.hasError) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'Hiba történt a munkaórák betöltésekor: ${snapshot.error}',
                                      style: TextStyle(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                  );
                                }

                                final summaries = snapshot.data ?? [];

                                if (summaries.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      'Még nincsenek munkanapló bejegyzések',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  );
                                }

                                return Column(
                                  children:
                                      summaries.map((summary) {
                                        return Card(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              child: Icon(Icons.person),
                                            ),
                                            title: Text(summary.employeeName),
                                            subtitle: Text(
                                              '${summary.entryCount} bejegyzés',
                                            ),
                                            trailing: Text(
                                              _formatDuration(
                                                summary.totalDuration,
                                              ),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ), //asdasdasd
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ProjectDataScreen(
                                  projectId: widget.projectId,
                                  projectName: widget.projectName,
                                ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'Adatok hozzáadása',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: null, // Button is disabled
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
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) {
      return '${hours}ó ${minutes}p';
    } else if (hours > 0) {
      return '${hours}ó';
    } else {
      return '${minutes}p';
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'ongoing':
        return 'Folyamatban';
      case 'done':
        return 'Kész';
      case 'maintenance':
        return 'Karbantartás';
      default:
        return 'Folyamatban';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ongoing':
        return Colors.blue;
      case 'done':
        return Colors.green;
      case 'maintenance':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  Widget _buildStatusChip(BuildContext context, String currentStatus) {
    return ActionChip(
      label: Text(_getStatusLabel(currentStatus)),
      avatar: Icon(
        Icons.circle,
        size: 12,
        color: _getStatusColor(currentStatus),
      ),
      onPressed: () => _showStatusBottomSheet(context, currentStatus),
      backgroundColor: _getStatusColor(currentStatus).withValues(alpha: 0.1),
      side: BorderSide(color: _getStatusColor(currentStatus)),
    );
  }

  void _showStatusBottomSheet(BuildContext context, String currentStatus) {
    String? selectedStatus = currentStatus;

    showModalBottomSheet(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Projekt állapotának módosítása',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      RadioListTile<String>(
                        title: const Text('Folyamatban'),
                        value: 'ongoing',
                        groupValue: selectedStatus,
                        onChanged: (value) {
                          setModalState(() {
                            selectedStatus = value;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Kész'),
                        value: 'done',
                        groupValue: selectedStatus,
                        onChanged: (value) {
                          setModalState(() {
                            selectedStatus = value;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Karbantartás'),
                        value: 'maintenance',
                        groupValue: selectedStatus,
                        onChanged: (value) {
                          setModalState(() {
                            selectedStatus = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Mégse'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () {
                              if (selectedStatus != null &&
                                  selectedStatus != currentStatus) {
                                Navigator.pop(context);
                                _showConfirmDialog(
                                  context,
                                  currentStatus,
                                  selectedStatus!,
                                );
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            child: const Text('Mentés'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  void _showConfirmDialog(
    BuildContext context,
    String oldStatus,
    String newStatus,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Állapot módosítása'),
            content: Text(
              'Biztosan megváltoztatod a projekt állapotát?  "${_getStatusLabel(oldStatus)}" -> "${_getStatusLabel(newStatus)}"',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Mégse'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateProjectStatus(newStatus);
                },
                child: const Text('Módosítás'),
              ),
            ],
          ),
    );
  }

  Future<void> _updateProjectStatus(String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({'projectStatus': newStatus});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Projekt állapota sikeresen frissítve: ${_getStatusLabel(newStatus)}',
          ),
        ),
      );

      // Frissítjük a képernyőt
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba történt a frissítéskor: $error')),
      );
    }
  }
}
