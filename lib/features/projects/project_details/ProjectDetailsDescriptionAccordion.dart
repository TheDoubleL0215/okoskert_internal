import 'package:flutter/material.dart';

class ProjectDetailsDescriptionAccordion extends StatelessWidget {
  final String projectDescription;
  const ProjectDetailsDescriptionAccordion({
    super.key,
    required this.projectDescription,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      expandedAlignment: Alignment.centerLeft,
      shape: RoundedRectangleBorder(),
      title: Text(
        "További információ",
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(projectDescription),
        ),
      ],
    );
  }
}
