import 'package:flutter/material.dart';
import 'package:okoskert_internal/app/workspace_provider.dart';
import 'package:okoskert_internal/core/utils/services/employee_service.dart';
import 'package:okoskert_internal/features/worklog/models/worklog_item_model.dart';
import 'package:okoskert_internal/features/worklog/services/worklog_save_service.dart';

class CreateNewWorklogViewModel extends ChangeNotifier {
  CreateNewWorklogViewModel({required WorkspaceProvider workspaceProvider})
    : _workspaceProvider = workspaceProvider {
    _loadEmployees();
    _initDefaultTimes();
  }

  final WorkspaceProvider _workspaceProvider;

  List<Map<String, dynamic>> _employees = [];
  final Set<String> _selectedEmployeeIds = <String>{};
  DateTime _date = DateTime.now();
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 1));
  String _description = '';

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  List<Map<String, dynamic>> get employees => _employees;
  Set<String> get selectedEmployeeIds => _selectedEmployeeIds;
  DateTime get date => _date;
  DateTime get startTime => _startTime;
  DateTime get endTime => _endTime;
  String get description => _description;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  Future<void> _loadEmployees() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _employees = await EmployeeService.getEmployees();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _initDefaultTimes() {
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _startTime = DateTime(now.year, now.month, now.day, now.hour, 0);
    _endTime = _startTime.add(const Duration(hours: 1));
  }

  void setSelectedEmployeeIds(Set<String> ids) {
    _selectedEmployeeIds
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  void setDate(DateTime value) {
    _date = DateTime(value.year, value.month, value.day);
    _startTime = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _startTime.hour,
      _startTime.minute,
    );
    _endTime = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _endTime.hour,
      _endTime.minute,
    );
    notifyListeners();
  }

  void setStartTime(DateTime value) {
    _startTime = value;
    notifyListeners();
  }

  void setEndTime(DateTime value) {
    _endTime = value;
    notifyListeners();
  }

  void setDescription(String value) {
    _description = value;
    notifyListeners();
  }

  /// Validáció: végidő legyen későbbi a kezdőidőnél, legyen legalább egy dolgozó.
  String? validate() {
    if (_selectedEmployeeIds.isEmpty) {
      return 'Válassz legalább egy dolgozót.';
    }
    if (!_endTime.isAfter(_startTime)) {
      return 'A végidőnek későbbinek kell lennie a kezdőidőnél.';
    }
    return null;
  }

  /// Új worklog mentése a workspace worklogs algyűjteményébe.
  Future<bool> save(BuildContext context) async {
    final validationError = validate();
    if (validationError != null) {
      _error = validationError;
      notifyListeners();
      return false;
    }

    final workspaceRef = _workspaceProvider.workspaceRef;
    if (workspaceRef == null) {
      _error = 'Nem található workspace.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final dateOnly = DateTime(_date.year, _date.month, _date.day);
      final workedMinutes = _endTime.difference(_startTime).inMinutes;
      final description = _description.trim();

      for (final employeeId in List<String>.from(_selectedEmployeeIds)) {
        final newItem = WorklogItemModel(
          id: '',
          employeeId: employeeId,
          description: description,
          date: dateOnly,
          workedMinutes: workedMinutes,
          startTime: _startTime,
          endTime: _endTime,
        );

        final result = await WorklogSaveService.createWorklog(
          workspaceRef: workspaceRef,
          item: newItem,
          context: context,
        );

        switch (result) {
          case WorklogSaveSuccess():
            break;
          case WorklogSaveFailure(:final message):
            _error = message;
            _isSaving = false;
            notifyListeners();
            return false;
          case WorklogSaveCancelled():
            _isSaving = false;
            notifyListeners();
            return false;
        }
      }

      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  static String formatDate(DateTime d) {
    return '${d.year}. ${d.month.toString().padLeft(2, '0')}. ${d.day.toString().padLeft(2, '0')}.';
  }

  static String formatTime(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
