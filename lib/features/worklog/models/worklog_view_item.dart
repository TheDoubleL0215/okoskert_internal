class WorklogViewItem {
  final String id;
  final String employeeId;
  final String? projectId;
  final String employeeName;
  final String? projectName;
  final String description;
  final DateTime date;
  final int workedMinutes;
  final DateTime? startTime;
  final DateTime? endTime;
  final int breakMinutes;

  WorklogViewItem({
    required this.id,
    required this.employeeName,
    required this.employeeId,
    this.projectId,
    this.projectName,
    required this.description,
    required this.date,
    required this.workedMinutes,
    this.startTime,
    this.endTime,
    this.breakMinutes = 0,
  });
}
