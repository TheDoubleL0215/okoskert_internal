import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:okoskert_internal/data/services/get_worklog_summary.dart';
import 'package:okoskert_internal/features/projects/create_project/CreateProjectScreen.dart';
import 'package:okoskert_internal/features/projects/project_details/ProjectDetailsContactDetails.dart';
import 'package:okoskert_internal/features/projects/project_details/ProjectDetailsDescriptionAccordion.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/ProjectDataScreen.dart';
import 'package:okoskert_internal/features/projects/project_details/ui/ProjectStatusChip.dart';

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
        actions: [
          FutureBuilder<int?>(
            future: UserService.getRole(),
            builder: (context, roleSnapshot) {
              final role = roleSnapshot.data;
              if (role == 1) {
                return TextButton(
                  child: const Text('Szerkesztés'),
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
                );
              }
              return const SizedBox.shrink();
            },
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
    return Column(
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

                const SizedBox(height: 12),

                padding16(
                  ProjectStatusChip(
                    context: context,
                    projectId: projectId,
                    currentStatus:
                        projectData['projectStatus'] as String? ?? 'ongoing',
                  ),
                ),

                if (projectData['customerPhone'] != null ||
                    projectData['customerEmail'] != null ||
                    projectData['projectLocation'] != null)
                  padding16(
                    ProjectDetailsContactDetails(
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

                padding16(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Munkaórák összesítése',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
        padding16(
          Column(
            children: [
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ProjectDataScreen(
                            projectId: projectId,
                            projectName: projectName,
                          ),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text(
                  'Adatok hozzáadása',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.download),
                label: const Text(
                  'Projekt adatainak exportálása',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
  }
}

// --- Small util widget ---
Widget padding16(Widget child) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child);

// --- Worklog section stays untouched ---
class WorklogSummarySection extends StatelessWidget {
  final String projectId;

  const WorklogSummarySection({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WorklogSummary>>(
      future: WorklogService.getWorklogSummaryByEmployee(projectId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }

        final summaries = snapshot.data!;
        if (summaries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Még nincsenek munkanapló bejegyzések'),
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
