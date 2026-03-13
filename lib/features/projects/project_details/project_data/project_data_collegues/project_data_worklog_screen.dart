import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/app/workspace_provider.dart';
import 'package:okoskert_internal/data/services/employee_name_service.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/project_data_collegues/ColleagueWorklogEntryEdit.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/project_data_collegues/ProjectAddDataCollegues.dart';
import 'package:okoskert_internal/features/worklog/models/worklog_item_model.dart';
import 'package:okoskert_internal/shared/widgets/worklog_entry_tile.dart';
import 'package:provider/provider.dart';

class ProjectDataWorklogScreen extends StatefulWidget {
  final String projectId;

  const ProjectDataWorklogScreen({super.key, required this.projectId});

  @override
  State<ProjectDataWorklogScreen> createState() =>
      _ProjectDataWorklogScreenState();
}

class _ProjectDataWorklogScreenState extends State<ProjectDataWorklogScreen> {
  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkspaceProvider>();
    final workspaceRef = wp.workspaceRef;

    if (wp.isLoading || workspaceRef == null) {
      if (wp.error != null && !wp.isLoading) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Hiba történt a workspace betöltésekor: ${wp.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }
      if (workspaceRef == null && !wp.isLoading) {
        return const Scaffold(
          body: Center(
            child: Text(
              'Nem található workspace a teamId alapján',
              style: TextStyle(fontSize: 16),
            ),
          ),
        );
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        label: const Text(
          'Új munkaóra hozzáadása',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      ProjectAddDataCollegues(projectId: widget.projectId),
            ),
          );
        },
        icon: const Icon(Icons.person_add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            workspaceRef
                .collection('worklogs')
                .where('assignedProjectId', isEqualTo: widget.projectId)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint(
              'Hiba történt a munkanapló betöltésekor: ${snapshot.error}',
            );
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Hiba történt a munkanapló betöltésekor: ${snapshot.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final worklogDocs = snapshot.data?.docs ?? [];

          if (worklogDocs.isEmpty) {
            return const Center(
              child: Text(
                'Még nincsenek munkanapló bejegyzések',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final groupedByDate =
              <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

          for (final doc in worklogDocs) {
            final data = doc.data();
            final date = data['date'] as Timestamp?;
            if (date != null) {
              final dateKey = _getDateKey(date.toDate());
              groupedByDate.putIfAbsent(dateKey, () => []).add(doc);
            }
          }

          final sortedDates =
              groupedByDate.keys.toList()..sort((a, b) => b.compareTo(a));

          final items = <_WorklogItem>[];
          for (final dateKey in sortedDates) {
            items.add(_WorklogItem.isHeader(dateKey));
            for (final doc in groupedByDate[dateKey]!) {
              items.add(_WorklogItem.isEntry(doc));
            }
          }

          final employeeIds =
              worklogDocs
                  .map(
                    (d) =>
                        (d.data()['employeeId'] ??
                                d.data()['employeeName'] ??
                                '')
                            as String,
                  )
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList();

          return FutureBuilder<Map<String, String>>(
            future: EmployeeNameService.getEmployeeNames(employeeIds),
            builder: (context, nameSnap) {
              final employeeNames = nameSnap.data ?? {};
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];

                  if (item.isHeader) {
                    final dateParts = item.dateKey!.split('-');
                    final formattedDate =
                        '${dateParts[0]}. ${dateParts[1]}. ${dateParts[2]}.';
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      child: Text(
                        formattedDate,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  }

                  final doc = item.doc!;
                  final data = doc.data();

                  final employeeId =
                      data['employeeId'] ?? data['employeeName'] ?? '';
                  final employeeName;
                  final startTime = data['startTime'] as Timestamp?;
                  final endTime = data['endTime'] as Timestamp?;
                  final breakMinutes = data['breakMinutes'] as int? ?? 0;
                  final date = data['date'] as Timestamp?;
                  final description = data['description'] as String? ?? '';
                  final worklogViewItem = WorklogItemModel(
                    id: doc.id,
                    employeeName:
                        employeeId.isEmpty
                            ? 'Ismeretlen'
                            : (employeeNames[employeeId] ?? employeeId),
                    employeeId: employeeId,
                    date: date?.toDate() ?? DateTime.now(),
                    workedMinutes:
                        startTime
                            ?.toDate()
                            .difference(endTime?.toDate() ?? DateTime.now())
                            .inMinutes ??
                        0,
                    startTime: startTime?.toDate() ?? DateTime.now(),
                    endTime: endTime?.toDate() ?? DateTime.now(),
                    breakMinutes: breakMinutes,
                    description: description,
                  );

                  return WorklogEntryTile(
                    item: worklogViewItem,
                    onTap:
                        () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder:
                              (context) =>
                                  EditWorklogBottomSheet(item: worklogViewItem),
                        ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _WorklogItem {
  final bool isHeader;
  final String? dateKey;
  final QueryDocumentSnapshot<Map<String, dynamic>>? doc;

  _WorklogItem._({required this.isHeader, this.dateKey, this.doc});

  factory _WorklogItem.isHeader(String dateKey) {
    return _WorklogItem._(isHeader: true, dateKey: dateKey);
  }

  factory _WorklogItem.isEntry(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return _WorklogItem._(isHeader: false, doc: doc);
  }
}
