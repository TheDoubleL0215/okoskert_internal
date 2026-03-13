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
  String? _selectedEmployeeId;
  DateTime _date = DateTime.now();
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 1));
  String _description = '';

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  List<Map<String, dynamic>> get employees => _employees;
  String? get selectedEmployeeId => _selectedEmployeeId;
  DateTime get date => _date;
  DateTime get startTime => _startTime;
  DateTime get endTime => _endTime;
  String get description => _description;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  /// Dolgozó megjelenített neve a kiválasztott id alapján.
  String? get selectedEmployeeLabel {
    if (_selectedEmployeeId == null) return null;
    for (final e in _employees) {
      if (e['id'] == _selectedEmployeeId) {
        return (e['name'] ?? e['email'] ?? e['id'])?.toString();
      }
    }
    return _selectedEmployeeId;
  }

  Future<void> _loadEmployees() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _employees = await EmployeeService.getEmployees();
      if (_employees.isNotEmpty && _selectedEmployeeId == null) {
        _selectedEmployeeId = _employees.first['id'] as String?;
      }
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

  void setSelectedEmployeeId(String? id) {
    _selectedEmployeeId = id;
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

  /// Validáció: végidő legyen későbbi a kezdőidőnél, legyen kiválasztott dolgozó.
  String? validate() {
    if (_selectedEmployeeId == null || _selectedEmployeeId!.isEmpty) {
      return 'Válassz dolgozót.';
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
      final newItem = WorklogItemModel(
        id: '',
        employeeId: _selectedEmployeeId!,
        description: _description.trim(),
        date: dateOnly,
        workedMinutes: _endTime.difference(_startTime).inMinutes,
        startTime: _startTime,
        endTime: _endTime,
      );

      final result = await WorklogSaveService.createWorklog(
        workspaceRef: workspaceRef,
        item: newItem,
        context: context,
      );

      _isSaving = false;
      notifyListeners();

      switch (result) {
        case WorklogSaveSuccess():
          return true;
        case WorklogSaveFailure(:final message):
          _error = message;
          return false;
        case WorklogSaveCancelled():
          return false;
      }
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
