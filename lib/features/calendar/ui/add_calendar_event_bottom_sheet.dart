import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';

class AddCalendarEventBottomSheet extends StatefulWidget {
  final DateTime selectedDate;
  final String? eventId;
  final String? initialType;
  final String? initialDescription;

  const AddCalendarEventBottomSheet({
    required this.selectedDate,
    this.eventId,
    this.initialType,
    this.initialDescription,
  });

  @override
  State<AddCalendarEventBottomSheet> createState() =>
      AddCalendarEventBottomSheetState();
}

class AddCalendarEventBottomSheetState
    extends State<AddCalendarEventBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late String _selectedType;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.initialDescription ?? '',
    );
    _selectedType = widget.initialType ?? 'Jegyzet';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final description = _descriptionController.text.trim();
      final eventData = {
        'teamId': await UserService.getTeamId(),
        'date': Timestamp.fromDate(
          DateTime(
            widget.selectedDate.year,
            widget.selectedDate.month,
            widget.selectedDate.day,
          ),
        ),
        'type': _selectedType,
        'description': description,
      };

      if (widget.eventId != null) {
        // Frissítés
        await FirebaseFirestore.instance
            .collection('calendar')
            .doc(widget.eventId)
            .update(eventData);
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bejegyzés sikeresen frissítve')),
        );
      } else {
        // Új létrehozása
        await FirebaseFirestore.instance.collection('calendar').add({
          ...eventData,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bejegyzés sikeresen elmentve')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba történt a mentéskor: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteEvent() async {
    if (widget.eventId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Bejegyzés törlése'),
            content: const Text('Biztosan törölni szeretnéd ezt a bejegyzést?'),
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

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('calendar')
          .doc(widget.eventId)
          .delete();

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bejegyzés sikeresen törölve')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba történt a törléskor: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.eventId != null
                  ? 'Bejegyzés szerkesztése'
                  : 'Új bejegyzés hozzáadása',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Jegyzet', label: Text('Jegyzet')),
                ButtonSegment(
                  enabled: false,
                  value: 'Anyagbeszerzés',
                  label: Text('Anyagbeszerzés'),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedType = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Leírás',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Kérjük, adja meg a leírást';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (widget.eventId != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isDeleting || _isSaving ? null : _deleteEvent,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child:
                          _isDeleting
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Törlés'),
                    ),
                  ),
                if (widget.eventId != null) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSaving || _isDeleting ? null : _saveEvent,
                    child:
                        _isSaving
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Mentés'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
