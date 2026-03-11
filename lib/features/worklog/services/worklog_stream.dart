import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okoskert_internal/data/services/employee_name_service.dart';
import 'package:okoskert_internal/features/worklog/models/worklog_view_item.dart';

/// Stream of worklogs for the given workspace, with project and employee names resolved.
/// [workspaceRef] – reference to the workspace document (e.g. from WorkspaceProvider).
/// [teamId] – used to load project names from the `projects` collection.
Stream<List<WorklogViewItem>> getHydratedWorklogs(
  DocumentReference<Map<String, dynamic>> workspaceRef,
  String teamId,
) {
  return workspaceRef
      .collection('worklogs')
      .orderBy('date', descending: true)
      .snapshots()
      .asyncMap((worklogSnap) async {
        final worklogDocs = worklogSnap.docs;

        if (worklogDocs.isEmpty) return <WorklogViewItem>[];

        // 1. Project names from `projects` collection (by teamId)
        final projectSnap =
            await FirebaseFirestore.instance
                .collection('projects')
                .where('teamId', isEqualTo: teamId)
                .get();

        final projectMap = {
          for (final doc in projectSnap.docs)
            doc.id: (doc.data()['projectName'] ?? doc.id) as String,
        };

        // 2. Employee names via EmployeeNameService (users collection)
        final employeeIds =
            worklogDocs
                .map(
                  (d) =>
                      (d.data()['employeeId'] ?? d.data()['employeeName'] ?? '')
                          as String,
                )
                .where((s) => s.isNotEmpty)
                .toSet()
                .toList();

        final employeeNames = await EmployeeNameService.getEmployeeNames(
          employeeIds,
        );

        // 3. Map worklog docs to WorklogViewItem
        return worklogDocs.map((doc) {
          final data = doc.data();
          final pId = data['assignedProjectId'] as String? ?? '';
          final uId =
              (data['employeeId'] ?? data['employeeName'] ?? '') as String? ??
              '';

          final date = data['date'] as Timestamp?;
          final startTime = data['startTime'] as Timestamp?;
          final endTime = data['endTime'] as Timestamp?;
          final breakMinutes = data['breakMinutes'] as int? ?? 0;

          int workedMinutes = 0;
          if (startTime != null && endTime != null) {
            workedMinutes =
                endTime.toDate().difference(startTime.toDate()).inMinutes -
                breakMinutes;
            if (workedMinutes < 0) workedMinutes = 0;
          }

          return WorklogViewItem(
            id: doc.id,
            employeeName: employeeNames[uId] ?? uId,
            projectName:
                projectMap[pId] ??
                (pId.isNotEmpty ? 'Projekt nem található' : ''),
            employeeId: uId,
            projectId: pId,
            description: (data['description'] as String?) ?? '',
            date: date?.toDate() ?? DateTime.now(),
            workedMinutes: workedMinutes,
            startTime: startTime?.toDate(),
            endTime: endTime?.toDate(),
            breakMinutes: breakMinutes,
          );
        }).toList();
      });
}
