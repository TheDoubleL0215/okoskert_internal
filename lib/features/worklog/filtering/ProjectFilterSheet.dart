import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProjectFilterSheet extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> projects;
  final Set<String> selectedIds;
  final Map<String, String> projectNames;

  const ProjectFilterSheet({
    required this.projects,
    required this.selectedIds,
    required this.projectNames,
  });

  @override
  State<ProjectFilterSheet> createState() => ProjectFilterSheetState();
}

class ProjectFilterSheetState extends State<ProjectFilterSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      minChildSize: 0.25,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Projektek szűrése',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: widget.projects.length,
                  itemBuilder: (context, index) {
                    final doc = widget.projects[index];
                    final id = doc.id;
                    final name = widget.projectNames[id] ?? id;
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _selected.contains(id),
                      title: Text(name),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(id);
                          } else {
                            _selected.remove(id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              Row(
                spacing: 16,
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Mégse'),
                    ),
                  ),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => Navigator.pop(context, _selected),
                      child: const Text('Alkalmaz'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
