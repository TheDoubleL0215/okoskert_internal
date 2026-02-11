import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';

enum MaintenanceStatus { active, done }

class MachineWorkHoursService {
  /// Óraállás mentése: workHoursLog, opcionálisan machineWorklog a projekthez,
  /// és a gép dokumentum hours + updatedAt frissítése.
  static Future<void> saveWorkHours({
    required String machineId,
    required double newHours,
    required DateTime date,
    required num previousHours,
    bool projectEnabled = false,
    String? assignedProjectId,
  }) async {
    final workHoursData = {
      'teamId': await UserService.getTeamId(),
      'date': Timestamp.fromDate(date),
      'previousHours': previousHours,
      'newHours': newHours,
      'machineId': machineId,
      'createdAt': FieldValue.serverTimestamp(),
      if (projectEnabled && assignedProjectId != null)
        'assignedProjectId': assignedProjectId,
    };

    await FirebaseFirestore.instance
        .collection('machines')
        .doc(machineId)
        .collection('workHoursLog')
        .add(workHoursData);

    if (projectEnabled && assignedProjectId != null) {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(assignedProjectId)
          .collection('machineWorklog')
          .add(workHoursData);
    }

    await FirebaseFirestore.instance
        .collection('machines')
        .doc(machineId)
        .update({'hours': newHours, 'updatedAt': FieldValue.serverTimestamp()});
  }

  static Future<void> logMaintenance({
    required Map<String, dynamic> maintenance,
    required String machineId,
    required DateTime date,
    required num hours,
    required String userId,
  }) async {
    final maintenanceData = {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'maintenanceName': maintenance['name'],
      'hours': hours,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await FirebaseFirestore.instance
        .collection('machines')
        .doc(machineId)
        .collection('maintenanceLog')
        .add(maintenanceData);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final machineRef = FirebaseFirestore.instance
          .collection('machines')
          .doc(machineId);

      final snapshot = await transaction.get(machineRef);

      if (!snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      List<dynamic> maintenances = List.from(data['maintenances'] ?? []);

      for (int i = 0; i < maintenances.length; i++) {
        if (maintenances[i]['name'] == maintenance['name']) {
          maintenances[i] = {...maintenances[i], 'lastAt': hours};
          break;
        }
      }

      transaction.update(machineRef, {'maintenances': maintenances});
    });
  }
}
