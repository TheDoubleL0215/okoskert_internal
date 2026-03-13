import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/app/workspace_provider.dart';
import 'package:okoskert_internal/features/worklog/models/worklog_item_model.dart';
import 'package:okoskert_internal/features/worklog/services/worklog_save_service.dart';
import 'package:provider/provider.dart';

// Bottom sheet a munkanapló bejegyzés szerkesztéséhez

class EditWorklogBottomSheet extends StatefulWidget {
  final WorklogItemModel item;

  const EditWorklogBottomSheet({super.key, required this.item});

  @override
  State<EditWorklogBottomSheet> createState() => EditWorklogBottomSheetState();
}

class EditWorklogBottomSheetState extends State<EditWorklogBottomSheet> {
  late DateTime _selectedStartTime;
  late DateTime _selectedEndTime;
  late DateTime _selectedDate;
  late TextEditingController _breakMinutesController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _dateController;
  late TextEditingController _descriptionController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedStartTime = widget.item.startTime;
    _selectedEndTime = widget.item.endTime;
    _selectedDate = widget.item.date;

    _breakMinutesController = TextEditingController(
      text: widget.item.breakMinutes.toString(),
    );
    _startTimeController = TextEditingController(
      text: _formatTimeOnly(_selectedStartTime),
    );
    _endTimeController = TextEditingController(
      text: _formatTimeOnly(_selectedEndTime),
    );
    _dateController = TextEditingController(text: _formatDate(_selectedDate));
    _descriptionController = TextEditingController(
      text: widget.item.description,
    );
  }

  @override
  void dispose() {
    _breakMinutesController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _dateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}. ${date.month.toString().padLeft(2, '0')}. ${date.day.toString().padLeft(2, '0')}.';
  }

  String _formatTimeOnly(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectStartTime() async {
    if (!mounted) return;
    final TimeOfDay? timePicked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedStartTime),
    );
    if (timePicked != null && mounted) {
      setState(() {
        _selectedStartTime = DateTime(
          _selectedStartTime.year,
          _selectedStartTime.month,
          _selectedStartTime.day,
          timePicked.hour,
          timePicked.minute,
        );
        _startTimeController.text = _formatTimeOnly(_selectedStartTime);
      });
    }
  }

  Future<void> _selectEndTime() async {
    if (!mounted) return;
    final TimeOfDay? timePicked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedEndTime),
    );
    if (timePicked != null && mounted) {
      setState(() {
        _selectedEndTime = DateTime(
          _selectedEndTime.year,
          _selectedEndTime.month,
          _selectedEndTime.day,
          timePicked.hour,
          timePicked.minute,
        );
        _endTimeController.text = _formatTimeOnly(_selectedEndTime);
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _dateController.text = _formatDate(_selectedDate);
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_isSaving || !mounted) return;

    if (_selectedEndTime.isBefore(_selectedStartTime) ||
        _selectedEndTime.isAtSameMomentAs(_selectedStartTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A végidőnek későbbinek kell lennie, mint a kezdőidő'),
        ),
      );
      return;
    }

    final breakMinutes = int.tryParse(_breakMinutesController.text) ?? 0;
    final dateOnly = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final startOnDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedStartTime.hour,
      _selectedStartTime.minute,
    );
    final endOnDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedEndTime.hour,
      _selectedEndTime.minute,
    );
    final workedMinutes =
        endOnDate.difference(startOnDate).inMinutes - breakMinutes;

    final itemToSave = WorklogItemModel(
      id: widget.item.id,
      employeeId: widget.item.employeeId,
      projectId: widget.item.projectId,
      description: _descriptionController.text.trim(),
      date: dateOnly,
      workedMinutes: workedMinutes > 0 ? workedMinutes : 0,
      startTime: startOnDate,
      endTime: endOnDate,
      breakMinutes: breakMinutes,
    );

    setState(() {
      _isSaving = true;
    });

    final workspaceRef = context.read<WorkspaceProvider>().workspaceRef;
    if (workspaceRef == null) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nem található workspace')));
      return;
    }

    final result = await WorklogSaveService.updateWorklog(
      workspaceRef: workspaceRef,
      item: itemToSave,
      context: context,
    );

    setState(() {
      _isSaving = false;
    });

    if (!mounted) return;

    switch (result) {
      case WorklogSaveSuccess():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bejegyzés sikeresen frissítve')),
        );
        Navigator.pop(context);
      case WorklogSaveFailure(:final message):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hiba: $message')));
      case WorklogSaveCancelled():
        break;
    }
  }

  Future<void> _deleteEntry() async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Bejegyzés törlése'),
            content: const Text(
              'Biztosan törölni szeretnéd ezt a bejegyzést? Ez a művelet nem vonható vissza.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Mégse'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Törlés'),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final workspaceRef = context.read<WorkspaceProvider>().workspaceRef;
      if (workspaceRef == null) {
        throw Exception('Nem található workspace a teamId alapján');
      }

      await workspaceRef.collection('worklogs').doc(widget.item.id).delete();

      await workspaceRef.update({'updatedAt': FieldValue.serverTimestamp()});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bejegyzés sikeresen törölve')),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hiba történt a törléskor: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Bejegyzés szerkesztése',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Kezdés dátum/idő választó
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startTimeController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Kezdés',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: _selectStartTime,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Vége dátum/idő választó
                  Expanded(
                    child: TextFormField(
                      controller: _endTimeController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Vége',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: _selectEndTime,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              // Szünet mező
              TextFormField(
                controller: _breakMinutesController,
                decoration: const InputDecoration(
                  labelText: 'Szünet (perc)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              // Dátum választó
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Dátum',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: _selectDate,
              ),
              const SizedBox(height: 16),
              // Leírás mező
              TextFormField(
                maxLines: 2,
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Leírás',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.sticky_note_2_outlined),
                ),
              ),
              const SizedBox(height: 24),
              // Mentés gomb
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isSaving ? null : _saveChanges,
                child:
                    _isSaving
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : const Text('Mentés'),
              ),
              const SizedBox(height: 8),
              // Törlés gomb
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isSaving ? null : _deleteEntry,
                icon: const Icon(Icons.delete),
                label: const Text('Törlés'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
