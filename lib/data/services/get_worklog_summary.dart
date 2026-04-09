import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okoskert_internal/data/services/employee_name_service.dart';

class WorklogSummary {
  final String employeeName;
  final Duration totalDuration;
  final int entryCount;

  WorklogSummary({
    required this.employeeName,
    required this.totalDuration,
    required this.entryCount,
  });
}

class _WorklogAgg {
  int totalMinutes = 0;
  int entryCount = 0;
}

class WorklogService {
  /// Összesíti a [workspaceRef]/worklogs bejegyzéseit a megadott projektre
  /// (`assignedProjectId`), dolgozó neve szerint. A `type == machines` sorok
  /// nem kerülnek bele.
  static Future<List<WorklogSummary>> getWorklogSummaryByEmployee({
    required DocumentReference<Map<String, dynamic>> workspaceRef,
    required String projectId,
  }) async {
    try {
      final querySnapshot =
          await workspaceRef
              .collection('worklogs')
              .where('assignedProjectId', isEqualTo: projectId)
              .get();

      final docs =
          querySnapshot.docs
              .where((d) => (d.data()['type'] as String?) != 'machines')
              .toList();
      if (docs.isEmpty) return <WorklogSummary>[];

      final employeeIds = <String>{};

      for (final doc in docs) {
        final data = doc.data();
        final eid = '${data['employeeId'] ?? ''}'.trim();
        if (eid.isNotEmpty) employeeIds.add(eid);
      }

      final employeeNames = await EmployeeNameService.getEmployeeNames(
        employeeIds.toList(),
      );

      String displayName(Map<String, dynamic> data) {
        final uid = '${data['employeeId'] ?? ''}'.trim();
        if (uid.isEmpty) {
          final en = (data['employeeName'] as String?)?.trim();
          if (en != null && en.isNotEmpty) return en;
          return 'Ismeretlen';
        }
        return employeeNames[uid] ?? uid;
      }

      int minutesWorked(Map<String, dynamic> data) {
        final wm = data['workedMinutes'];
        if (wm is num && wm.round() > 0) {
          return wm.round();
        }
        final start = data['startTime'] as Timestamp?;
        final end = data['endTime'] as Timestamp?;
        final breakM = (data['breakMinutes'] as num?)?.toInt() ?? 0;
        if (start != null && end != null) {
          var m = end.toDate().difference(start.toDate()).inMinutes - breakM;
          if (m < 0) m = 0;
          return m;
        }
        return 0;
      }

      final totals = <String, _WorklogAgg>{};
      for (final doc in docs) {
        final data = doc.data();
        final m = minutesWorked(data);
        if (m <= 0) continue;
        final name = displayName(data);
        final agg = totals.putIfAbsent(name, _WorklogAgg.new);
        agg.totalMinutes += m;
        agg.entryCount++;
      }

      final summaries =
          totals.entries
              .map(
                (e) => WorklogSummary(
                  employeeName: e.key,
                  totalDuration: Duration(minutes: e.value.totalMinutes),
                  entryCount: e.value.entryCount,
                ),
              )
              .toList();

      summaries.sort((a, b) => a.employeeName.compareTo(b.employeeName));
      return summaries;
    } catch (e) {
      rethrow;
    }
  }
}
