import 'package:cloud_firestore/cloud_firestore.dart';

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

class WorklogService {
  /// Lekérdezi a projekt worklog adatait és összesíti alkalmazott neve szerint
  ///
  /// [projectId] - A projekt dokumentum ID-ja
  /// Visszatér a munkaórák összesítésével alkalmazott neve szerint csoportosítva
  static Future<List<WorklogSummary>> getWorklogSummaryByEmployee(
    String projectId,
  ) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('worklog')
          .get();

      // Csoportosítás alkalmazott neve szerint
      final groupedByEmployee = <String, List<Map<String, dynamic>>>{};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final employeeName = data['employeeName'] as String? ?? 'Ismeretlen';
        groupedByEmployee.putIfAbsent(employeeName, () => []).add(data);
      }

      // Összesítés minden alkalmazottra
      final summaries = <WorklogSummary>[];

      for (final entry in groupedByEmployee.entries) {
        final employeeName = entry.key;
        final entries = entry.value;

        Duration totalDuration = Duration.zero;
        int entryCount = 0;

        for (final entryData in entries) {
          final startTime = entryData['startTime'] as Timestamp?;
          final endTime = entryData['endTime'] as Timestamp?;
          final breakMinutes = entryData['breakMinutes'] as int? ?? 0;

          if (startTime != null && endTime != null) {
            final start = startTime.toDate();
            final end = endTime.toDate();
            final duration = end.difference(start);
            // Levonjuk a szünetet
            final workDuration = duration - Duration(minutes: breakMinutes);
            totalDuration += workDuration;
            entryCount++;
          }
        }

        summaries.add(
          WorklogSummary(
            employeeName: employeeName,
            totalDuration: totalDuration,
            entryCount: entryCount,
          ),
        );
      }

      // Rendezés alkalmazott neve szerint
      summaries.sort((a, b) => a.employeeName.compareTo(b.employeeName));

      return summaries;
    } catch (e) {
      rethrow;
    }
  }
}

