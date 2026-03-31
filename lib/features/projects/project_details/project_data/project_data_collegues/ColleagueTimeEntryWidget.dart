import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/core/utils/services/employee_service.dart';
import 'package:okoskert_internal/features/calendar/ui/employee_selection_bottom_sheet.dart';
import 'package:okoskert_internal/features/calendar/ui/selected_employees_section.dart';

class ColleagueTimeEntryWidget extends StatefulWidget {
  final Function(Map<String, dynamic>)? onChanged;

  const ColleagueTimeEntryWidget({super.key, this.onChanged});

  @override
  State<ColleagueTimeEntryWidget> createState() =>
      _ColleagueTimeEntryWidgetState();
}

class _ColleagueTimeEntryWidgetState extends State<ColleagueTimeEntryWidget> {
  static const int _pickerMinuteInterval = 5;

  final List<String> _selectedEmployeeIds = [];
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isDisposed = false;
  late final TextEditingController _breakMinutesController;
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _startTimeController = TextEditingController();
    _endTimeController = TextEditingController();
    _breakMinutesController = TextEditingController();
    _descriptionController = TextEditingController();
    _loadEmployees();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _startTimeController.dispose();
    _endTimeController.dispose();
    _breakMinutesController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await EmployeeService.getEmployees();
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba történt a dolgozók betöltésekor: $e')),
        );
      }
    }
  }

  static DateTime _timeOfDayToPickerDateTime(TimeOfDay t) {
    return DateTime(2000, 1, 1, t.hour, t.minute);
  }

  static TimeOfDay _pickerDateTimeToTimeOfDay(DateTime dt) {
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }

  /// [CupertinoDatePicker] megköveteli, hogy `initialDateTime.minute % minuteInterval == 0`.
  static DateTime _snapToMinuteInterval(DateTime t, int intervalMinutes) {
    final totalMinutes = t.hour * 60 + t.minute;
    var snapped =
        ((totalMinutes + intervalMinutes ~/ 2) ~/ intervalMinutes) *
        intervalMinutes;
    final maxSnapped = 24 * 60 - intervalMinutes;
    if (snapped > maxSnapped) snapped = maxSnapped;
    return DateTime(t.year, t.month, t.day, snapped ~/ 60, snapped % 60);
  }

  Future<TimeOfDay?> _showCupertinoTimePicker(TimeOfDay initial) async {
    var selected = _snapToMinuteInterval(
      _timeOfDayToPickerDateTime(initial),
      _pickerMinuteInterval,
    );

    return showCupertinoModalPopup<TimeOfDay?>(
      context: context,
      builder: (BuildContext ctx) {
        final bottom = MediaQuery.paddingOf(ctx).bottom;
        return Container(
          padding: EdgeInsets.only(bottom: bottom),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onPressed: () {
                      Navigator.pop(
                        ctx,
                        _pickerDateTimeToTimeOfDay(
                          _timeOfDayToPickerDateTime(initial),
                        ),
                      );
                    },
                    child: const Text('Mégse'),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onPressed: () {
                      Navigator.pop(ctx, _pickerDateTimeToTimeOfDay(selected));
                    },
                    child: const Text('Kész'),
                  ),
                ],
              ),
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  minuteInterval: _pickerMinuteInterval,
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: selected,
                  onDateTimeChanged: (DateTime dt) {
                    selected = DateTime(2000, 1, 1, dt.hour, dt.minute);
                    _pickerDateTimeToTimeOfDay(selected);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectStartTime() async {
    if (!mounted) return;
    final picked = await _showCupertinoTimePicker(
      _startTime ??
          TimeOfDay.fromDateTime(
            DateTime.now().subtract(const Duration(hours: 8)),
          ),
    );
    if (picked != null && picked != _startTime && mounted) {
      setState(() {
        _startTime = picked;
        _startTimeController.text = _formatTimeOfDay(picked);
      });
      _notifyChanged();
    }
  }

  Future<void> _selectEndTime() async {
    if (!mounted) return;
    final picked = await _showCupertinoTimePicker(_endTime ?? TimeOfDay.now());
    if (picked != null && picked != _endTime && mounted) {
      setState(() {
        _endTime = picked;
        _endTimeController.text = _formatTimeOfDay(picked);
      });
      _notifyChanged();
    }
  }

  void _notifyChanged() {
    if (_isDisposed || !mounted) return;
    widget.onChanged?.call(_getData());
  }

  void _openEmployeePicker() {
    if (_employees.isEmpty) return;
    showEmployeeSelectionBottomSheet(
      context: context,
      availableEmployees: _employees,
      initialSelectedIds: _selectedEmployeeIds.toSet(),
      onSelectionChanged: (ids) {
        if (!mounted) return;
        setState(() {
          _selectedEmployeeIds
            ..clear()
            ..addAll(ids);
        });
        _notifyChanged();
      },
    );
  }

  Map<String, dynamic> _getData() {
    return {
      'employeeIds': List<String>.from(_selectedEmployeeIds),
      'startTime':
          _startTime != null
              ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
              : null,
      'endTime':
          _endTime != null
              ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
              : null,
      'breakMinutes': int.tryParse(
        _breakMinutesController.text.trim().isEmpty
            ? '0'
            : _breakMinutesController.text.trim(),
      ),
      'description': _descriptionController.text.trim(),
    };
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_employees.isEmpty)
            const Text('Nincsenek elérhető dolgozók')
          else
            SelectedEmployeesSection(
              isProjectDetails: true,
              availableEmployees: _employees,
              assignedEmployeeIds: _selectedEmployeeIds,
              onEditPressed: _openEmployeePicker,
            ),
          const SizedBox(height: 16),
          // Kezdés időválasztó
          Row(
            spacing: 16,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _startTimeController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelStyle: Theme.of(context).textTheme.bodyLarge,
                    labelText: 'Kezdés',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                    hintText: 'Válassz időt',
                  ),
                  onTap: _selectStartTime,
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: _endTimeController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelStyle: Theme.of(context).textTheme.bodyLarge,
                    labelText: 'Vége',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                    hintText: 'Válassz időt',
                  ),
                  onTap: _selectEndTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Szünet (perc) mező
          TextFormField(
            controller: _breakMinutesController,
            decoration: InputDecoration(
              labelStyle: Theme.of(context).textTheme.bodyLarge,
              labelText: 'Szünet (perc)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => _notifyChanged(),
          ),
          const SizedBox(height: 16),
          // Leírás mező
          TextFormField(
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            controller: _descriptionController,
            decoration: InputDecoration(
              labelStyle: Theme.of(context).textTheme.bodyLarge,
              labelText: 'Leírás',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _notifyChanged(),
          ),
        ],
      ),
    );
  }
}
