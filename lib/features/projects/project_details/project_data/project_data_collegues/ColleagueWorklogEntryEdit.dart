import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Bottom sheet a munkanapló bejegyzés szerkesztéséhez

class EditWorklogBottomSheet extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String projectId;
  final DateTime? initialStartTime;
  final DateTime? initialEndTime;
  final int initialBreakMinutes;
  final DateTime? initialDate;

  const EditWorklogBottomSheet({
    super.key,
    required this.doc,
    required this.projectId,
    this.initialStartTime,
    this.initialEndTime,
    this.initialBreakMinutes = 0,
    this.initialDate,
  });

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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedStartTime = widget.initialStartTime ?? DateTime.now();
    _selectedEndTime = widget.initialEndTime ?? DateTime.now();
    _selectedDate = widget.initialDate ?? DateTime.now();

    _breakMinutesController = TextEditingController(
      text: widget.initialBreakMinutes.toString(),
    );
    _startTimeController = TextEditingController(
      text: _formatTimeOnly(_selectedStartTime),
    );
    _endTimeController = TextEditingController(
      text: _formatTimeOnly(_selectedEndTime),
    );
    _dateController = TextEditingController(text: _formatDate(_selectedDate));
  }

  @override
  void dispose() {
    _breakMinutesController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _dateController.dispose();
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

    // Validáció
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

    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('worklog')
          .doc(widget.doc.id)
          .update({
            'startTime': _selectedStartTime,
            'endTime': _selectedEndTime,
            'breakMinutes': breakMinutes,
            'date': DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
            ),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bejegyzés sikeresen frissítve')),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba történt a frissítéskor: $e')),
      );
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
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
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
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('worklog')
          .doc(widget.doc.id)
          .delete();

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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bejegyzés szerkesztése',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            // Kezdés dátum/idő választó
            TextFormField(
              controller: _startTimeController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Kezdés',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: _selectStartTime,
            ),
            const SizedBox(height: 16),
            // Vége dátum/idő választó
            TextFormField(
              controller: _endTimeController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Vége',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: _selectEndTime,
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
            const SizedBox(height: 24),
            // Mentés gomb
            FilledButton(
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
            const SizedBox(height: 12),
            // Törlés gomb
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _deleteEntry,
              icon: const Icon(Icons.delete),
              label: const Text('Törlés'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
