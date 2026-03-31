import 'package:cloud_firestore/cloud_firestore.dart';

class WorklogItemModel {
  final String id;
  final String employeeId;
  final String? projectId;
  final String? employeeName;
  final String? projectName;
  final String? type;
  final String description;
  final DateTime date;
  final int workedMinutes;
  final DateTime startTime;
  final DateTime endTime;
  final int breakMinutes;

  WorklogItemModel({
    required this.id,
    this.employeeName,
    required this.employeeId,
    this.projectId,
    this.projectName,
    this.type,
    required this.description,
    required this.date,
    required this.workedMinutes,
    required this.startTime,
    required this.endTime,
    this.breakMinutes = 0,
  });

  factory WorklogItemModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return WorklogItemModel(
      id: documentId,
      employeeId: map['employeeId'] ?? '',
      projectId: map['assignedProjectId'],
      description: map['description'] ?? '',

      // Cast to Timestamp, then convert to DateTime
      date: (map['date'] as Timestamp).toDate(),
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),

      workedMinutes: map['workedMinutes'] ?? 0,
      breakMinutes: map['breakMinutes'] ?? 0,
      employeeName: map['employeeName'],
      projectName: map['projectName'],
      type: map['type'] as String?,
    );
  }

  WorklogItemModel copyWith({
    DateTime? startTime,
    DateTime? endTime,
    int? workedMinutes,
  }) {
    return WorklogItemModel(
      id: id,
      employeeId: employeeId,
      projectId: projectId,
      description: description,
      date: date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      workedMinutes: workedMinutes ?? this.workedMinutes,
      breakMinutes: breakMinutes,
      employeeName: employeeName,
      projectName: projectName,
      type: type,
    );
  }

  // --- EXISTING toMap ---

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'assignedProjectId': projectId,
      'description': description,
      'date': date,
      'workedMinutes': workedMinutes,
      'startTime': startTime,
      'endTime': endTime,
      'breakMinutes': breakMinutes,
      'type': type,
    };
  }
}
