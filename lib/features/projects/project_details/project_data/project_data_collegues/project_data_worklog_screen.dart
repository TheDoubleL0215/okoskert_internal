import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/app/session_provider.dart';
import 'package:okoskert_internal/app/workspace_provider.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:okoskert_internal/data/services/employee_name_service.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/project_data_collegues/ColleagueWorklogEntryEdit.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/project_data_collegues/project_create_worklog_screen.dart';
import 'package:okoskert_internal/features/worklog/models/worklog_item_model.dart';
import 'package:okoskert_internal/shared/widgets/worklog_entry_tile.dart';
import 'package:provider/provider.dart';

class ProjectDataWorklogScreen extends StatefulWidget {
  final String projectId;

  const ProjectDataWorklogScreen({super.key, required this.projectId});

  @override
  State<ProjectDataWorklogScreen> createState() =>
      _ProjectDataWorklogScreenState();
}

class _ProjectDataWorklogScreenState extends State<ProjectDataWorklogScreen> {
  /// Egyedi Hero-tag példányonként (TabBarView / több route miatt ne ütközzön).
  final Object _fabHeroTag = Object();
  int _selectedSegment = 0;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final role = session.role;
    final wp = context.watch<WorkspaceProvider>();
    final workspaceRef = wp.workspaceRef;

    if (wp.isLoading || workspaceRef == null) {
      if (wp.error != null && !wp.isLoading) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Hiba történt a workspace betöltésekor: ${wp.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }
      if (workspaceRef == null && !wp.isLoading) {
        return const Scaffold(
          body: Center(
            child: Text(
              'Nem található workspace a teamId alapján',
              style: TextStyle(fontSize: 16),
            ),
          ),
        );
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      floatingActionButton:
          role != 3
              ? FloatingActionButton.extended(
                heroTag: _fabHeroTag,
                label: Text(
                  _selectedSegment == 1
                      ? 'Új gépmunkaidő hozzáadása'
                      : 'Új bejegyzés hozzáadása',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  if (_selectedSegment == 1) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder:
                          (_) => _AddMachineWorklogBottomSheet(
                            workspaceRef: workspaceRef,
                            projectId: widget.projectId,
                          ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ProjectAddDataCollegues(
                            projectId: widget.projectId,
                          ),
                    ),
                  );
                },
                icon: Icon(
                  _selectedSegment == 1 ? Icons.agriculture : Icons.person_add,
                ),
              )
              : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                style: ButtonStyle(
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  ),
                ),
                segments: const [
                  ButtonSegment<int>(value: 0, label: Text('Kollégák')),
                  ButtonSegment<int>(value: 1, label: Text('Gépek')),
                ],
                selected: <int>{_selectedSegment},
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) return;
                  setState(() => _selectedSegment = selection.first);
                },
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  (() {
                    Query<Map<String, dynamic>> query = workspaceRef
                        .collection('worklogs')
                        .where(
                          'assignedProjectId',
                          isEqualTo: widget.projectId,
                        );

                    if (_selectedSegment == 1) {
                      query = query.where('type', isEqualTo: 'machines');
                    }

                    return query.snapshots();
                  })(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  debugPrint(
                    'Hiba történt a munkanapló betöltésekor: ${snapshot.error}',
                  );
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Hiba történt a munkanapló betöltésekor: ${snapshot.error}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final allWorklogDocs = snapshot.data?.docs ?? [];
                final worklogDocs =
                    allWorklogDocs.where((doc) {
                      final type = doc.data()['type'] as String?;
                      if (_selectedSegment == 1) {
                        return type == 'machines';
                      }
                      return type != 'machines';
                    }).toList();

                if (worklogDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Még nincsenek munkanapló bejegyzések',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                final groupedByDate =
                    <
                      String,
                      List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    >{};

                for (final doc in worklogDocs) {
                  final data = doc.data();
                  final date = data['date'] as Timestamp?;
                  if (date != null) {
                    final dateKey = _getDateKey(date.toDate());
                    groupedByDate.putIfAbsent(dateKey, () => []).add(doc);
                  }
                }

                final sortedDates =
                    groupedByDate.keys.toList()..sort((a, b) => b.compareTo(a));

                final items = <_WorklogItem>[];
                for (final dateKey in sortedDates) {
                  items.add(_WorklogItem.isHeader(dateKey));
                  for (final doc in groupedByDate[dateKey]!) {
                    items.add(_WorklogItem.isEntry(doc));
                  }
                }

                final employeeIds =
                    _selectedSegment == 1
                        ? <String>[]
                        : worklogDocs
                            .map(
                              (d) =>
                                  (d.data()['employeeId'] ??
                                          d.data()['employeeName'] ??
                                          '')
                                      as String,
                            )
                            .where((s) => s.isNotEmpty)
                            .toSet()
                            .toList();
                final machineIds =
                    _selectedSegment == 1
                        ? worklogDocs
                            .map((d) => (d.data()['machineId'] ?? '') as String)
                            .where((s) => s.isNotEmpty)
                            .toSet()
                            .toList()
                        : <String>[];

                return FutureBuilder<Map<String, String>>(
                  future:
                      _selectedSegment == 1
                          ? _getMachineNamesByIds(machineIds)
                          : EmployeeNameService.getEmployeeNames(employeeIds),
                  builder: (context, nameSnap) {
                    if (nameSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final names = nameSnap.data ?? {};
                    final listBottomInset =
                        MediaQuery.paddingOf(context).bottom +
                        (role != 3 ? 88 : 16);
                    return ListView.separated(
                      padding: EdgeInsets.only(bottom: listBottomInset),
                      separatorBuilder:
                          (_, __) => const Divider(thickness: 1, height: 0),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];

                        if (item.isHeader) {
                          final dateParts = item.dateKey!.split('-');
                          final formattedDate =
                              '${dateParts[0]}. ${dateParts[1]}. ${dateParts[2]}.';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainer,
                            ),
                            child: Text(
                              formattedDate,
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          );
                        }

                        final doc = item.doc!;
                        final data = doc.data();

                        final isMachineEntry =
                            (data['type'] as String?) == 'machines';
                        final employeeId =
                            isMachineEntry
                                ? (data['machineId'] as String? ?? '')
                                : (data['employeeId'] ??
                                        data['employeeName'] ??
                                        '')
                                    as String;
                        final fallbackName =
                            isMachineEntry
                                ? (data['machineName'] as String? ??
                                    'Ismeretlen gép')
                                : 'Ismeretlen';
                        final employeeName =
                            employeeId.isEmpty
                                ? fallbackName
                                : (names[employeeId] ?? fallbackName);
                        final startTime = data['startTime'] as Timestamp?;
                        final endTime = data['endTime'] as Timestamp?;
                        final breakMinutes = data['breakMinutes'] as int? ?? 0;
                        final date = data['date'] as Timestamp?;
                        final description =
                            data['description'] as String? ?? '';
                        final projectId =
                            data['assignedProjectId'] as String? ?? '';
                        final worklogViewItem = WorklogItemModel(
                          id: doc.id,
                          employeeName: employeeName,
                          employeeId: employeeId,
                          projectId: projectId,
                          date: date?.toDate() ?? DateTime.now(),
                          workedMinutes:
                              startTime
                                  ?.toDate()
                                  .difference(
                                    endTime?.toDate() ?? DateTime.now(),
                                  )
                                  .inMinutes ??
                              0,
                          startTime: startTime?.toDate() ?? DateTime.now(),
                          endTime: endTime?.toDate() ?? DateTime.now(),
                          breakMinutes: breakMinutes,
                          description: description,
                        );

                        return WorklogEntryTile(
                          item: worklogViewItem,
                          onTap:
                              () => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder:
                                    (context) => EditWorklogBottomSheet(
                                      isEditable: role != 3,
                                      item: worklogViewItem,
                                    ),
                              ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<Map<String, String>> _getMachineNamesByIds(
    List<String> machineIds,
  ) async {
    if (machineIds.isEmpty) return {};

    final futures = machineIds.map((id) async {
      final doc =
          await FirebaseFirestore.instance.collection('machines').doc(id).get();
      final data = doc.data();
      final name = data?['name'] as String?;
      return MapEntry(id, name ?? '');
    });

    final entries = await Future.wait(futures);
    return Map<String, String>.fromEntries(
      entries.where((entry) => entry.value.isNotEmpty),
    );
  }
}

class _WorklogItem {
  final bool isHeader;
  final String? dateKey;
  final QueryDocumentSnapshot<Map<String, dynamic>>? doc;

  _WorklogItem._({required this.isHeader, this.dateKey, this.doc});

  factory _WorklogItem.isHeader(String dateKey) {
    return _WorklogItem._(isHeader: true, dateKey: dateKey);
  }

  factory _WorklogItem.isEntry(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return _WorklogItem._(isHeader: false, doc: doc);
  }
}

class _AddMachineWorklogBottomSheet extends StatefulWidget {
  const _AddMachineWorklogBottomSheet({
    required this.workspaceRef,
    required this.projectId,
  });

  final DocumentReference<Map<String, dynamic>> workspaceRef;
  final String projectId;

  @override
  State<_AddMachineWorklogBottomSheet> createState() =>
      _AddMachineWorklogBottomSheetState();
}

class _AddMachineWorklogBottomSheetState
    extends State<_AddMachineWorklogBottomSheet> {
  late final Future<String?> _teamIdFuture;
  final Map<String, String> _selectedMachines = {};
  late DateTime _selectedDate;
  late DateTime _selectedStartTime;
  late DateTime _selectedEndTime;
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _teamIdFuture = UserService.getTeamId();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedStartTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      now.hour,
      0,
    );
    _selectedEndTime = _selectedStartTime.add(const Duration(hours: 1));
    _dateController.text = _formatDate(_selectedDate);
    _startTimeController.text = _formatTime(_selectedStartTime);
    _endTimeController.text = _formatTime(_selectedEndTime);
  }

  @override
  void dispose() {
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}. ${date.month.toString().padLeft(2, '0')}. ${date.day.toString().padLeft(2, '0')}.';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      selectableDayPredicate: (date) => date.isBefore(DateTime.now()),
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _dateController.text = _formatDate(_selectedDate);
      _selectedStartTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedStartTime.hour,
        _selectedStartTime.minute,
      );
      _selectedEndTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedEndTime.hour,
        _selectedEndTime.minute,
      );
    });
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime({
    required DateTime initialValue,
    required ValueChanged<DateTime> onSelected,
  }) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        DateTime tempPicked = initialValue;
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Mégse'),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      onSelected(tempPicked);
                      Navigator.pop(context);
                    },
                    child: const Text('Kész'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  minuteInterval: 5,
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: initialValue,
                  use24hFormat: true,
                  onDateTimeChanged: (value) {
                    tempPicked = value;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;

    if (_selectedMachines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Válassz ki legalább egy gépet')),
      );
      return;
    }

    if (_selectedEndTime.isBefore(_selectedStartTime) ||
        _selectedEndTime.isAtSameMomentAs(_selectedStartTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A végidőnek későbbinek kell lennie a kezdésnél'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final dateOnly = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final machine in _selectedMachines.entries) {
        final docRef = widget.workspaceRef.collection('worklogs').doc();
        batch.set(docRef, {
          'type': 'machines',
          'machineId': machine.key,
          'machineName': machine.value,
          // WorklogEntryTile kompatibilitás: ezeket a kulcsokat is használja.
          'employeeId': machine.key,
          'startTime': _selectedStartTime,
          'endTime': _selectedEndTime,
          'breakMinutes': 0,
          'date': dateOnly,
          'assignedProjectId': widget.projectId,
          'description': _descriptionController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      await widget.workspaceRef.update({
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_selectedMachines.length} gép munkaideje sikeresen elmentve',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hiba mentés közben: $e')));
    }
  }

  Future<void> _openMachinesSelector(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> machines,
  ) async {
    final tempSelected = {..._selectedMachines};
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              bottom: false,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          Text(
                            'Gép(ek) kiválasztása',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: machines.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final machine = machines[index];
                          final machineId = machine.id;
                          final machineName =
                              machine.data()['name'] as String? ??
                              'Névtelen gép';
                          final isSelected = tempSelected.containsKey(
                            machineId,
                          );

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            title: Text(machineName),
                            trailing: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primary
                                          : Theme.of(context).dividerColor,
                                  width: 1.5,
                                ),
                              ),
                              child:
                                  isSelected
                                      ? Icon(
                                        Icons.check,
                                        size: 14,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                      )
                                      : null,
                            ),
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  tempSelected.remove(machineId);
                                } else {
                                  tempSelected[machineId] = machineName;
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        MediaQuery.of(context).viewPadding.bottom + 8,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => Navigator.pop(context, tempSelected),
                          child: const Text('Kész'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;
    setState(() {
      _selectedMachines
        ..clear()
        ..addAll(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final role = session.role;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Text(
                      role != 3
                          ? 'Gépmunkaidő szerkesztése'
                          : 'Gépmunkaidő részletei',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<String?>(
                future: _teamIdFuture,
                builder: (context, teamSnap) {
                  final teamId = teamSnap.data;
                  if (teamSnap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    );
                  }
                  if (teamId == null || teamId.isEmpty) {
                    return const Text('Nem található team azonosító.');
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('machines')
                            .where('teamId', isEqualTo: teamId)
                            .snapshots(),
                    builder: (context, machineSnap) {
                      if (machineSnap.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        );
                      }

                      final machines = machineSnap.data?.docs ?? [];
                      if (machines.isEmpty) {
                        return const Text('Nincsenek elérhető gépek.');
                      }

                      final validIds = machines.map((m) => m.id).toSet();
                      if (_selectedMachines.keys.any(
                        (id) => !validIds.contains(id),
                      )) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() {
                            _selectedMachines.removeWhere(
                              (id, _) => !validIds.contains(id),
                            );
                          });
                        });
                      }

                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openMachinesSelector(machines),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Gépek kiválasztása',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.keyboard_arrow_up),
                          ),
                          child:
                              _selectedMachines.isEmpty
                                  ? Text(
                                    'Koppints a választáshoz',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                                  )
                                  : Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children:
                                        _selectedMachines.entries.map((entry) {
                                          return InputChip(
                                            label: Text(entry.value),
                                            onDeleted:
                                                () => setState(
                                                  () => _selectedMachines
                                                      .remove(entry.key),
                                                ),
                                          );
                                        }).toList(),
                                  ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Dátum',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                onTap: _selectDate,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startTimeController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Kezdés',
                        border: OutlineInputBorder(),
                      ),
                      onTap: () async {
                        await _pickTime(
                          initialValue: _selectedStartTime,
                          onSelected: (picked) {
                            setState(() {
                              _selectedStartTime = DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                _selectedDate.day,
                                picked.hour,
                                picked.minute,
                              );
                              _startTimeController.text = _formatTime(
                                _selectedStartTime,
                              );
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _endTimeController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Vége',
                        border: OutlineInputBorder(),
                      ),
                      onTap: () async {
                        await _pickTime(
                          initialValue: _selectedEndTime,
                          onSelected: (picked) {
                            setState(() {
                              _selectedEndTime = DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                _selectedDate.day,
                                picked.hour,
                                picked.minute,
                              );
                              _endTimeController.text = _formatTime(
                                _selectedEndTime,
                              );
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Leírás',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isSaving ? null : _save,
                child:
                    _isSaving
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Mentés'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
