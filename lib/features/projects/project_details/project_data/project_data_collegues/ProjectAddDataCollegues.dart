import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/project_data_collegues/ColleagueTimeEntryWidget.dart';

class ProjectAddDataCollegues extends StatefulWidget {
  final String projectId;
  const ProjectAddDataCollegues({super.key, required this.projectId});

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

  List<String> _employeeIdsFromEntry(Map<String, dynamic> entry) {
    final raw = entry['employeeIds'] as List?;
    if (raw == null) return [];
    return raw.map((e) => e.toString()).toList();
  }

  /// Érintő időpontok (pl. vége 12:00, másik kezdete 12:00) nem számítanak átfedésnek.
  bool _intervalsOverlap(
    DateTime startA,
    DateTime endA,
    DateTime startB,
    DateTime endB,
  ) {
    return startA.isBefore(endB) && startB.isBefore(endA);
  }

  DateTime? _readFirestoreDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Future<void> _saveWorkLog() async {
    if (_timeEntries.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nincsenek időbejegyzések a mentéshez')),
      );
      return;
    }

    for (var i = 0; i < _timeEntries.length; i++) {
      final entry = _timeEntries[i];
      final startTimeString = entry['startTime'] as String?;
      final endTimeString = entry['endTime'] as String?;
      final breakMinutes = entry['breakMinutes'] as int? ?? 0;
      final employeeIds = _employeeIdsFromEntry(entry);

      if (employeeIds.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'A ${i + 1}. időbejegyzésben nincs kiválasztott dolgozó!',
            ),
          ),
        );
        return;
      }

      if (startTimeString == null || endTimeString == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'A ${i + 1}. időbejegyzésben nincs kiválasztva kezdés és/vagy végidő!',
            ),
          ),
        );
        return;
      }

      final startDateTime = _parseTimeString(startTimeString, _selectedDate);
      final endDateTime = _parseTimeString(endTimeString, _selectedDate);

      if (endDateTime.isBefore(startDateTime) ||
          endDateTime.isAtSameMomentAs(startDateTime)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'A ${i + 1}. időbejegyzésnél a végidőnek későbbinek kell lennie a kezdőidőnél!',
            ),
          ),
        );
        return;
      }

      final workDurationMinutes =
          endDateTime.difference(startDateTime).inMinutes;
      if (breakMinutes > workDurationMinutes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'A ${i + 1}. időbejegyzésnél a szünet hosszabb, mint a ledolgozott idő!',
            ),
          ),
        );
        return;
      }
    }

    for (var i = 0; i < _timeEntries.length; i++) {
      final startA = _parseTimeString(
        _timeEntries[i]['startTime'] as String,
        _selectedDate,
      );
      final endA = _parseTimeString(
        _timeEntries[i]['endTime'] as String,
        _selectedDate,
      );
      final idsA = _employeeIdsFromEntry(_timeEntries[i]).toSet();
      for (var j = i + 1; j < _timeEntries.length; j++) {
        final idsB = _employeeIdsFromEntry(_timeEntries[j]).toSet();
        if (!idsA.any(idsB.contains)) continue;
        final startB = _parseTimeString(
          _timeEntries[j]['startTime'] as String,
          _selectedDate,
        );
        final endB = _parseTimeString(
          _timeEntries[j]['endTime'] as String,
          _selectedDate,
        );
        if (_intervalsOverlap(startA, endA, startB, endB)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'A ${i + 1}. és a ${j + 1}. időbejegyzés átfedi egymás idejét '
                'legalább egy közös dolgozónál.',
              ),
            ),
          );
          return;
        }
      }
    }

    final teamId = await UserService.getTeamId();
    if (teamId == null || teamId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hiba: nem található teamId')),
      );
      return;
    }

    final workspaceQuery =
        await FirebaseFirestore.instance
            .collection('workspaces')
            .where('teamId', isEqualTo: teamId)
            .limit(1)
            .get();

    if (workspaceQuery.docs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hiba: nem található workspace a teamId-hoz'),
        ),
      );
      return;
    }

    final worklogRef = workspaceQuery.docs.first.reference.collection(
      'worklogs',
    );

    final plainDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final targetDateTimestamp = Timestamp.fromDate(plainDate);

    final recordsToDeleteById =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    final conflictingEntryIndices = <int>{};

    for (var i = 0; i < _timeEntries.length; i++) {
      final entry = _timeEntries[i];
      final newStart = _parseTimeString(
        entry['startTime'] as String,
        _selectedDate,
      );
      final newEnd = _parseTimeString(
        entry['endTime'] as String,
        _selectedDate,
      );

      for (final employeeId in _employeeIdsFromEntry(entry)) {
        if (employeeId.isEmpty) continue;

        final existing =
            await worklogRef
                .where('employeeId', isEqualTo: employeeId)
                .where('date', isEqualTo: targetDateTimestamp)
                .get();

        for (final doc in existing.docs) {
          final data = doc.data();
          final pid = data['assignedProjectId'] as String?;
          if (pid != widget.projectId) continue;

          final exStart = _readFirestoreDateTime(data['startTime']);
          final exEnd = _readFirestoreDateTime(data['endTime']);
          if (exStart == null || exEnd == null) continue;

          if (!_intervalsOverlap(newStart, newEnd, exStart, exEnd)) continue;

          recordsToDeleteById[doc.id] = doc;
          conflictingEntryIndices.add(i);
        }
      }
    }

    if (recordsToDeleteById.isNotEmpty) {
      if (!mounted) return;

      final shouldOverwrite = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Átfedő idősáv'),
              content: Text(
                conflictingEntryIndices.length == 1
                    ? 'A ${conflictingEntryIndices.first + 1}. időbejegyzéshez kiválasztott dolgozó(k)nak már van erre a napra, ebben a projektben olyan munkanapló sora, amelynek ideje átfedi az új idősávot (${_formatDate(_selectedDate)}).\n\nFelülírod az átfedő meglévő bejegyzéseket?'
                    : 'Több időbejegyzéshez is található átfedő meglévő munkanapló sor ebben a projektben (${_formatDate(_selectedDate)}).\n\nFelülírod ezeket az átfedő bejegyzéseket?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Mégse'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Felülírás'),
                ),
              ],
            ),
      );

      if (shouldOverwrite != true) {
        return;
      }
    }

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final doc in recordsToDeleteById.values) {
        batch.delete(doc.reference);
      }

      for (final entry in _timeEntries) {
        final startTimeString = entry['startTime'] as String;
        final endTimeString = entry['endTime'] as String;
        final breakMinutes = entry['breakMinutes'] as int? ?? 0;
        final description = entry['description'] as String? ?? '';

        final startDateTime = _parseTimeString(startTimeString, _selectedDate);
        final endDateTime = _parseTimeString(endTimeString, _selectedDate);

        for (final employeeId in _employeeIdsFromEntry(entry).toSet()) {
          if (employeeId.isEmpty) continue;

          final docRef = worklogRef.doc();
          batch.set(docRef, {
            'employeeId': employeeId,
            'startTime': startDateTime,
            'endTime': endDateTime,
            'breakMinutes': breakMinutes,
            'date': plainDate,
            'assignedProjectId': widget.projectId,
            'createdAt': FieldValue.serverTimestamp(),
            'description': description,
          });
        }
      }

      await batch.commit();

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({'updatedAt': FieldValue.serverTimestamp()});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Munkanapló bejegyzések sikeresen elmentve'),
        ),
      );
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
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Text(
                        '${index + 1}. időbejegyzés',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _addTimeEntry,
                  icon: const Icon(Icons.add),
                  label: const Text('Időbejegyzés hozzáadása'),
                ),
                Spacer(),
                FilledButton(
                  onPressed: _saveWorkLog,
                  child: const Text('Mentés'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
