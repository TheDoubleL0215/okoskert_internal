import 'package:flutter/material.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:okoskert_internal/data/services/get_project_by_id.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/ProjectDataScreen.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
      appBar: AppBar(title: Text(widget.projectName)),
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
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FilledButton.tonalIcon(
                              label: Text("${projectData['customerPhone']}"),
                              onPressed: () {
                                launchUrlString(
                                  'tel:${projectData['customerPhone']}',
                                );
                              },
                              icon: Icon(Icons.phone),
                            ),
                            FilledButton.tonalIcon(
                              label: Text(
                                "${projectData['projectLocation']}",
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              onPressed: () {
                                MapsLauncher.launchQuery(
                                  projectData['projectLocation'],
                                );
                              },
                              icon: Icon(Icons.directions),
                            ),
                            FilledButton.tonalIcon(
                              label: Text(
                                "${projectData['customerEmail']}",
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              onPressed: () {
                                launchUrlString(
                                  'mailto:${projectData['customerEmail']}',
                                );
                              },
                              icon: Icon(Icons.email),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                      label: const Text('Adatok hozzáadása'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: null, // Button is disabled
                      icon: const Icon(Icons.download),
                      label: const Text('Projekt adatainak exportálása'),
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

  Widget _buildDetailCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return ListTile(
      leading: Icon(icon, size: 24),
      title: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'ongoing':
        return 'Folyamatban';
      case 'done':
        return 'Kész';
      case 'maintenance':
        return 'Karbantartás';
      default:
        return status;
    }
  }
}
