import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/project_data_collegues/ColleagueTimeEntryWidget.dart';

class ProjectAddDataCollegues extends StatefulWidget {
  final String projectId;
  final String projectName;
  const ProjectAddDataCollegues({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ProjectAddDataCollegues> createState() =>
      _ProjectAddDataColleguesState();
}

class _ProjectAddDataColleguesState extends State<ProjectAddDataCollegues> {
  final List<Map<String, dynamic>> _timeEntries = [];
  DateTime _selectedDate = DateTime.now();
  late final TextEditingController _dateController;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: _formatDate(_selectedDate));
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}. ${date.month.toString().padLeft(2, '0')}. ${date.day.toString().padLeft(2, '0')}.';
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDate(picked);
      });
    }
  }

  void _onTimeEntryChanged(int index, Map<String, dynamic> data) {
    if (index < _timeEntries.length) {
      setState(() {
        _timeEntries[index] = data;
      });
    }
  }

  void _addTimeEntry() {
    setState(() {
      _timeEntries.add({});
    });
  }

  void _removeTimeEntry(int index) {
    setState(() {
      _timeEntries.removeAt(index);
    });
  }

  /// Parszol egy idő stringet (pl. "10:00") és kombinálja a dátummal
  DateTime _parseTimeString(String timeString, DateTime date) {
    final parts = timeString.split(':');
    if (parts.length != 2) {
      throw FormatException('Érvénytelen idő formátum: $timeString');
    }
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Elmenti a munkanapló bejegyzéseket Firestore-ba
  Future<void> _saveWorkLog() async {
    // Validáció: ellenőrizzük, hogy vannak-e bejegyzések
    if (_timeEntries.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nincsenek időbejegyzések a mentéshez')),
      );
      return;
    }

    // Validáció: ellenőrizzük, hogy minden bejegyzés teljes-e
    for (var i = 0; i < _timeEntries.length; i++) {
      final entry = _timeEntries[i];
      if (entry['employeeId'] == null ||
          entry['startTime'] == null ||
          entry['endTime'] == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'A ${i + 1}. időbejegyzés nem teljes. Kérjük, töltse ki az összes mezőt.',
            ),
          ),
        );
        return;
      }
    }

    try {
      final worklogRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('worklog');

      // Batch write a jobb teljesítményért
      final batch = FirebaseFirestore.instance.batch();

      for (final entry in _timeEntries) {
        final employeeId = entry['employeeId'] as String;
        final startTimeString = entry['startTime'] as String;
        final endTimeString = entry['endTime'] as String;
        final breakMinutes = entry['breakMinutes'] as int? ?? 0;

        // Parse-oljuk az időket és kombináljuk a dátummal
        final startDateTime = _parseTimeString(startTimeString, _selectedDate);
        final endDateTime = _parseTimeString(endTimeString, _selectedDate);

        // Ellenőrizzük, hogy a végidő későbbi legyen, mint a kezdőidő
        if (endDateTime.isBefore(startDateTime) ||
            endDateTime.isAtSameMomentAs(startDateTime)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'A végidőnek későbbinek kell lennie, mint a kezdőidő',
              ),
            ),
          );
          return;
        }

        // Új dokumentum referencia a worklog alcollekcióban
        final docRef = worklogRef.doc();

        // Adatok összeállítása
        final workLogData = {
          'employeeName': employeeId,
          'startTime':
              startDateTime, // Firestore automatikusan Timestamp-ekké konvertálja
          'endTime':
              endDateTime, // Firestore automatikusan Timestamp-ekké konvertálja
          'breakMinutes': breakMinutes,
          'date': DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
          ), // Dátum is timestamp-ként mentve (éjfél)
          'createdAt': FieldValue.serverTimestamp(), // Létrehozás ideje
        };

        batch.set(docRef, workLogData);
      }

      // Batch commit
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Munkanapló bejegyzések sikeresen elmentve'),
        ),
      );

      // Vissza a projekt részletek képernyőre
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hiba történt a mentéskor: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          "Új bejegyzés",
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FilledButton(
              onPressed: _saveWorkLog,
              child: const Text(
                'Mentés',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dátumválasztó
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
            // Többször használható időbejegyzés widget-ek
            ...List.generate(
              _timeEntries.length,
              (index) => Card(
                child: Column(
                  children: [
                    ColleagueTimeEntryWidget(
                      onChanged: (data) => _onTimeEntryChanged(index, data),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _removeTimeEntry(index),
                          icon: const Icon(Icons.delete),
                          label: const Text('Törlés'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Új időbejegyzés hozzáadása gomb
            OutlinedButton.icon(
              onPressed: _addTimeEntry,
              icon: const Icon(Icons.add),
              label: const Text('Időbejegyzés hozzáadása'),
            ),
          ],
        ),
      ),
    );
  }
}
