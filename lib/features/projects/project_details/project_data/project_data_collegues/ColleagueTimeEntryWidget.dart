import 'package:flutter/material.dart';
import 'package:okoskert_internal/data/services/get_employees.dart';

class ColleagueTimeEntryWidget extends StatefulWidget {
  final Function(Map<String, dynamic>)? onChanged;

  const ColleagueTimeEntryWidget({super.key, this.onChanged});

  @override
  State<ColleagueTimeEntryWidget> createState() =>
      _ColleagueTimeEntryWidgetState();
}

class _ColleagueTimeEntryWidgetState extends State<ColleagueTimeEntryWidget> {
  String? _selectedEmployeeName;
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isDisposed = false;
  late final TextEditingController _breakMinutesController;
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;

  @override
  void initState() {
    super.initState();
    _startTimeController = TextEditingController();
    _endTimeController = TextEditingController();
    _breakMinutesController = TextEditingController();
    _loadEmployees();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _startTimeController.dispose();
    _endTimeController.dispose();
    _breakMinutesController.dispose();
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

  Future<void> _selectStartTime() async {
    if (!mounted) return;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
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
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(),
    );
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

  Map<String, dynamic> _getData() {
    return {
      'employeeId': _selectedEmployeeName,
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
    };
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dolgozó dropdown
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_employees.isEmpty)
            const Text('Nincsenek elérhető dolgozók')
          else
            DropdownButtonFormField<String>(
              initialValue: _selectedEmployeeName,
              decoration: const InputDecoration(
                labelText: 'Dolgozó',
                border: OutlineInputBorder(),
              ),
              items:
                  _employees.map((employee) {
                    final name = employee['name'] as String? ?? 'Névtelen';
                    return DropdownMenuItem(value: name, child: Text(name));
                  }).toList(),
              onChanged: (value) {
                if (!mounted) return;
                setState(() {
                  _selectedEmployeeName = value;
                });
                _notifyChanged();
              },
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
                  decoration: const InputDecoration(
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
                  decoration: const InputDecoration(
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
            decoration: const InputDecoration(
              labelText: 'Szünet (perc)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => _notifyChanged(),
          ),
        ],
      ),
    );
  }
}
