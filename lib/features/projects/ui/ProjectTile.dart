import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/ProjectDataScreen.dart';
import 'package:okoskert_internal/features/projects/project_details/project_details_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Widget buildProjectList(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
  String sectionName,
) {
  final filteredDocs =
      allDocs.where((doc) {
        final data = doc.data();
        final status = data['projectStatus'] as String?;
        return status == sectionName;
      }).toList();

  if (filteredDocs.isEmpty) {
    return Center(
      child: Text(
        'Nincs projekt ebben a kategóriában',
        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
      ),
    );
  }

  return ListView.separated(
    padding: const EdgeInsets.symmetric(vertical: 8),
    itemCount: filteredDocs.length,
    separatorBuilder: (_, __) => const Divider(),
    itemBuilder: (context, index) {
      final data = filteredDocs[index].data();
      final projectName = (data['projectName'] ?? '') as String;
      final projectLocation = (data['projectLocation'] ?? '') as String;

      const double trailingWidth = 56;

      return Material(
        color: Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ProjectDataScreen(
                            projectId: filteredDocs[index].id,
                            projectName: projectName,
                          ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        projectName.isEmpty ? 'Névtelen projekt' : projectName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 0,
                        ),
                      ),
                      if (projectLocation.isNotEmpty)
                        Text(
                          projectLocation,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: trailingWidth,
              height: 72,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ProjectDetailsScreen(
                            projectId: filteredDocs[index].id,
                            projectName: projectName,
                          ),
                    ),
                  );
                },
                child: Center(child: Icon(LucideIcons.info)),
              ),
            ),
          ],
        ),
      );
    },
  );
}
