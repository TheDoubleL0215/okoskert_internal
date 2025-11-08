import 'package:flutter/material.dart';
import 'package:okoskert_internal/data/services/get_project_by_id.dart';
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

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    // TODO: Projekt adatainak exportálása funkció implementálása
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Projekt adatainak exportálása'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
