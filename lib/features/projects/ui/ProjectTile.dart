import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okoskert_internal/features/projects/project_details/ProjectDetailsScreen.dart';

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
        'Nincs projekt ebben a szakaszban',
        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
      ),
    );
  }

  return ListView.separated(
    padding: const EdgeInsets.all(8),
    itemCount: filteredDocs.length,
    separatorBuilder: (_, __) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final data = filteredDocs[index].data();
      final projectName = (data['projectName'] ?? '') as String;
      final projectLocation = (data['projectLocation'] ?? '') as String;

      return ListTile(
        title: Text(
          projectName.isEmpty ? 'Névtelen projekt' : projectName,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 0,
          ),
        ),
        subtitle: Text(projectLocation),
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
      );
    },
  );
}
