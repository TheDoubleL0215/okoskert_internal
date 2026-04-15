import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okoskert_internal/data/services/employee_name_service.dart';
import 'package:okoskert_internal/features/worklog/models/worklog_item_model.dart';

/// Stream of worklogs for the given workspace, with project and employee names resolved.
/// [workspaceRef] – reference to the workspace document (e.g. from WorkspaceProvider).
/// [teamId] – used to load project names from the `projects` collection.
Stream<List<WorklogItemModel>> getHydratedWorklogs(
  DocumentReference<Map<String, dynamic>> workspaceRef,
  String teamId,
) {
  return workspaceRef
      .collection('worklogs')
      .orderBy('date', descending: true)
      .snapshots()
      .asyncMap((worklogSnap) async {
        final worklogDocs = worklogSnap.docs;

        if (worklogDocs.isEmpty) return <WorklogItemModel>[];

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

        final wageTypeSnap = await workspaceRef.collection('wageTypes').get();
        final wageTypeNamesById = <String, String>{
          for (final doc in wageTypeSnap.docs)
            doc.id: (doc.data()['name'] as String?) ?? '',
        };

        // 2/b. Machine names from `machines` collection (for type == 'machines')
        final machineIds =
            worklogDocs
                .where((d) => (d.data()['type'] as String?) == 'machines')
                .map(
                  (d) =>
                      (d.data()['machineId'] ?? d.data()['employeeId'] ?? '')
                          as String,
                )
                .where((s) => s.isNotEmpty)
                .toSet()
                .toList();

        final machineNameMap = <String, String>{};
        if (machineIds.isNotEmpty) {
          final machineDocs = await Future.wait(
            machineIds.map(
              (id) =>
                  FirebaseFirestore.instance
                      .collection('machines')
                      .doc(id)
                      .get(),
            ),
          );
          for (final doc in machineDocs) {
            final data = doc.data();
            final name = data?['name'] as String?;
            if (doc.id.isNotEmpty && name != null && name.isNotEmpty) {
              machineNameMap[doc.id] = name;
            }
          }
        }

        // 3. Map worklog docs to WorklogViewItem
        return worklogDocs.map((doc) {
          final data = doc.data();
          final pId = data['assignedProjectId'] as String? ?? '';
          final uId =
              (data['employeeId'] ?? data['employeeName'] ?? '') as String? ??
              '';
          final isMachine = (data['type'] as String?) == 'machines';
          final machineId =
              (data['machineId'] ?? data['employeeId'] ?? '') as String? ?? '';
          final displayName =
              isMachine
                  ? (machineNameMap[machineId] ??
                      (data['machineName'] as String?) ??
                      machineId)
                  : (employeeNames[uId] ?? uId);
          final wageTypeId = data['wageTypeId'] as String?;
          final wageTypeName =
              wageTypeId == null ? null : wageTypeNamesById[wageTypeId];

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

          return WorklogItemModel(
            id: doc.id,
            employeeName: displayName,
            projectName:
                projectMap[pId] ??
                (pId.isNotEmpty ? 'Projekt nem található' : ''),
            employeeId: uId,
            projectId: pId,
            description: (data['description'] as String?) ?? '',
            date: date?.toDate() ?? DateTime.now(),
            workedMinutes: workedMinutes,
            startTime: startTime?.toDate() ?? DateTime.now(),
            endTime: endTime?.toDate() ?? DateTime.now(),
            breakMinutes: breakMinutes,
            type: data['type'] as String?,
            wageTypeId: wageTypeId,
            wageTypeName: wageTypeName,
          );
        }).toList();
      });
}
