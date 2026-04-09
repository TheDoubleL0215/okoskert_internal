import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/core/utils/services/employee_service.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:okoskert_internal/data/services/workspace_service.dart';
import 'package:okoskert_internal/features/calendar/ui/employee_selection_bottom_sheet.dart';
import 'package:okoskert_internal/features/calendar/ui/selected_employees_section.dart';

class AddCalendarPostScreen extends StatefulWidget {
  final DateTime selectedDate;
  final String? eventId;
  final String? initialType;
  final int? initialPriority;
  final String? initialTitle;
  final String? initialDescription;
  final List<String>? initialAssignedEmployees;
  final List<String>? initialAssignedProjects;
  final List<Map<String, dynamic>>? initialSubtasks;

  /// Ha hiányzik, egy napos esemény: [selectedDate] napja.
  final DateTime? initialEndDate;
  const AddCalendarPostScreen({
    super.key,
    required this.selectedDate,
    this.initialTitle,
    this.eventId,
    this.initialType,
    this.initialDescription,
    this.initialAssignedEmployees,
    this.initialAssignedProjects,
    this.initialPriority,
    this.initialSubtasks,
    this.initialEndDate,
  });

  @override
  State<AddCalendarPostScreen> createState() => AddCalendarPostScreenState();
}

class AddCalendarPostScreenState extends State<AddCalendarPostScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  List<Map<String, dynamic>> _availableEmployees = [];
  late String _selectedType;
  late int _selectedPriority;
  List<String> _assignedEmployees = [];
  List<String> _selectedProjectIds = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _subtasks = [];
  final Map<String, TextEditingController> _subtaskControllers = {};
  bool _isLoadingProjects = false;
  bool _isSaving = false;
  bool _isDeleting = false;

  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  late bool _isMultiDay;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _formatHuDate(DateTime d) =>
      '${d.year}. ${d.month.toString().padLeft(2, '0')}. ${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _rangeStart = _dateOnly(widget.selectedDate);
    final initialEnd =
        widget.initialEndDate != null
            ? _dateOnly(widget.initialEndDate!)
            : _rangeStart;
    _rangeEnd = initialEnd.isBefore(_rangeStart) ? _rangeStart : initialEnd;
    _isMultiDay =
        _rangeStart.year != _rangeEnd.year ||
        _rangeStart.month != _rangeEnd.month ||
        _rangeStart.day != _rangeEnd.day;
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _descriptionController = TextEditingController(
      text: widget.initialDescription ?? '',
    );
    _selectedType = widget.initialType ?? 'Jegyzet';
    _selectedPriority = widget.initialPriority ?? 0;

    // Részfeladatok betöltése
    if (widget.initialSubtasks != null && widget.initialSubtasks!.isNotEmpty) {
      _subtasks =
          widget.initialSubtasks!.asMap().entries.map((entry) {
            final index = entry.key;
            final subtask = entry.value;
            // Ha nincs id, generálunk egyet (index-et is használunk, hogy egyedi legyen)
            if (!subtask.containsKey('id') || subtask['id'] == null) {
              return {
                ...subtask,
                'id': '${DateTime.now().millisecondsSinceEpoch}_$index',
              };
            }
            return subtask;
          }).toList();

      // TextEditingController-ek létrehozása a meglévő részfeladatokhoz
      for (final subtask in _subtasks) {
        final id = subtask['id'] as String;
        final title = subtask['title'] as String? ?? '';
        _subtaskControllers[id] = TextEditingController(text: title);
      }
    } else {
      _subtasks = [];
    }

    // Először próbáljuk az új mezőket (assignedEmployees, assignedProjects)
    // Ha nincsenek, akkor a régi mezőket (tags, projectId) használjuk (backward compatibility)
    _assignedEmployees =
        widget.initialAssignedEmployees != null
            ? List<String>.from(widget.initialAssignedEmployees!)
            : (widget.initialAssignedEmployees != null
                ? List<String>.from(widget.initialAssignedEmployees!)
                : []);
    _selectedProjectIds =
        widget.initialAssignedProjects != null
            ? List<String>.from(widget.initialAssignedProjects!)
            : (widget.initialAssignedProjects != null
                ? widget.initialAssignedProjects!
                : []);
    _loadProjects();
    _loadAvailableEmployees();
  }

  Future<void> _loadAvailableEmployees() async {
    // Load colleagues from Firestore users collection
    try {
      final employees = await EmployeeService.getEmployees();

      if (mounted) {
        setState(() {
          _availableEmployees = employees;
        });
      }
    } catch (e) {
      debugPrint('Hiba a munkatársak lekérdezésekor: $e');
    }
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoadingProjects = true;
    });

    try {
      final teamId = await UserService.getTeamId();
      if (teamId == null || teamId.isEmpty) {
        return;
      }

      final snapshot =
          await FirebaseFirestore.instance
              .collection('projects')
              .where('teamId', isEqualTo: teamId)
              .get();

      if (mounted) {
        setState(() {
          _projects =
              snapshot.docs.map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'name': data['projectName'] as String? ?? 'Névtelen projekt',
                  'status': data['status'] as String? ?? 'ongoing',
                };
              }).toList();
          // Rendezés név szerint
          _projects.sort((a, b) => a['name']!.compareTo(b['name']!));
          _isLoadingProjects = false;
        });
      }
    } catch (error) {
      if (mounted) {
        debugPrint('Hiba a projektek betöltésekor: $error');
        setState(() {
          _isLoadingProjects = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hiba történt a projektek betöltésekor: $error'),
          ),
        );
      }
    }
  }

  void _addSubtask() {
    final String id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _subtasks.add({'id': id, 'title': '', 'status': 'ongoing'});
      _subtaskControllers[id] = TextEditingController();
    });
  }

  void _toggleSubtaskStatus(int index) {
    setState(() {
      final currentStatus = _subtasks[index]['status'] as String;
      _subtasks[index]['status'] = currentStatus == 'done' ? 'ongoing' : 'done';
    });
  }

  void _removeSubtask(int index) {
    final subtask = _subtasks[index];
    final id = subtask['id'] as String;
    _subtaskControllers[id]?.dispose();
    _subtaskControllers.remove(id);
    setState(() {
      _subtasks.removeAt(index);
    });
  }

  List<String> _nonEmptySubtaskTitles() {
    return _subtasks
        .map((subtask) {
          final id = subtask['id'] as String;
          return _subtaskControllers[id]?.text.trim() ?? '';
        })
        .where((t) => t.isNotEmpty)
        .toList();
  }

  Future<void> _saveSubtaskScheme() async {
    final titles = _nonEmptySubtaskTitles();
    if (titles.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A séma mentéséhez legalább egy megnevezett részfeladat kell.',
          ),
        ),
      );
      return;
    }

    final workspaceRef = await WorkspaceService.getWorkspaceRefForCurrentTeam();
    if (workspaceRef == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nem található munkatér a csapathoz.')),
      );
      return;
    }

    if (!mounted) return;

    final schemeName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _SaveSubtaskSchemeNameDialog(),
    );

    if (schemeName == null || schemeName.isEmpty) {
      return;
    }

    try {
      await workspaceRef.collection('subtaskScheme').add({
        'name': schemeName,
        'taskNames': titles,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('„$schemeName” séma elmentve.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Séma mentése sikertelen: $e')));
    }
  }

  void _appendSubtasksFromNames(List<String> names) {
    if (names.isEmpty) return;
    setState(() {
      var base = DateTime.now().microsecondsSinceEpoch;
      for (var i = 0; i < names.length; i++) {
        final trimmed = names[i].trim();
        if (trimmed.isEmpty) continue;
        final id = '${base}_$i';
        base++;
        _subtasks.add({'id': id, 'title': trimmed, 'status': 'ongoing'});
        _subtaskControllers[id] = TextEditingController(text: trimmed);
      }
    });
  }

  Future<void> _showSubtaskSchemesSheet() async {
    final workspaceRef = await WorkspaceService.getWorkspaceRefForCurrentTeam();
    if (workspaceRef == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nem található munkatér a csapathoz.')),
      );
      return;
    }

    QuerySnapshot<Map<String, dynamic>>? snapshot;
    try {
      snapshot = await workspaceRef.collection('subtaskScheme').get();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sémák betöltése sikertelen: $e')));
      return;
    }

    if (!mounted) return;

    final schemes =
        snapshot.docs.map((doc) {
            final data = doc.data();
            final name = data['name'] as String? ?? doc.id;
            final taskNames =
                (data['taskNames'] as List?)?.map((e) => '$e').toList() ??
                <String>[];
            return {'id': doc.id, 'name': name, 'taskNames': taskNames};
          }).toList()
          ..sort(
            (a, b) => (a['name'] as String).toLowerCase().compareTo(
              (b['name'] as String).toLowerCase(),
            ),
          );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final modalSchemes =
            schemes.map((e) => Map<String, dynamic>.from(e)).toList();
        String? selectedId;
        var isEditing = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final listHeight = MediaQuery.of(context).size.height * 0.45;
            final bottomInset = MediaQuery.of(sheetContext).viewPadding.bottom;

            Future<void> deleteScheme(String docId, String schemeName) async {
              try {
                await workspaceRef
                    .collection('subtaskScheme')
                    .doc(docId)
                    .delete();
                if (!sheetContext.mounted) return;
                setModalState(() {
                  modalSchemes.removeWhere((s) => s['id'] == docId);
                  if (selectedId == docId) {
                    selectedId = null;
                  }
                });
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('„$schemeName” törölve.')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Séma törlése sikertelen: $e')),
                );
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + bottomInset,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Mentett sémák',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            isEditing = !isEditing;
                            if (!isEditing) {
                              selectedId = null;
                            }
                          });
                        },
                        child: Text(isEditing ? 'Kész' : 'Szerkesztés'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: listHeight,
                    child:
                        modalSchemes.isEmpty
                            ? const Center(
                              child: Text(
                                'Még nincs mentett részfeladat-séma.',
                              ),
                            )
                            : ListView.builder(
                              itemCount: modalSchemes.length,
                              itemBuilder: (context, index) {
                                final s = modalSchemes[index];
                                final id = s['id']! as String;
                                final name = s['name']! as String;
                                final count = (s['taskNames'] as List).length;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  selected: !isEditing && selectedId == id,
                                  title: Text(name),
                                  subtitle: Text('$count részfeladat'),
                                  trailing:
                                      isEditing
                                          ? IconButton(
                                            icon: Icon(
                                              Icons.delete_outline,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.error,
                                            ),
                                            onPressed: () {
                                              deleteScheme(id, name);
                                            },
                                          )
                                          : null,
                                  onTap:
                                      isEditing
                                          ? null
                                          : () {
                                            setModalState(() {
                                              selectedId = id;
                                            });
                                          },
                                );
                              },
                            ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed:
                        isEditing || selectedId == null
                            ? null
                            : () {
                              final chosen = modalSchemes.firstWhere(
                                (s) => s['id'] == selectedId,
                              );
                              final names = List<String>.from(
                                chosen['taskNames'] as List,
                              );
                              Navigator.pop(sheetContext);
                              _appendSubtasksFromNames(names);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Séma részfeladatai betöltve.'),
                                ),
                              );
                            },
                    child: const Text('Séma használata'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _titleController.dispose();
    for (final controller in _subtaskControllers.values) {
      controller.dispose();
    }
    _subtaskControllers.clear();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _rangeStart,
      firstDate: DateTime(2010),
      lastDate: DateTime(2030, 12, 31),
      locale: const Locale('hu', 'HU'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _rangeStart = _dateOnly(picked);
      if (!_isMultiDay) {
        _rangeEnd = _rangeStart;
      } else if (_rangeEnd.isBefore(_rangeStart)) {
        _rangeEnd = _rangeStart;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _rangeEnd.isBefore(_rangeStart) ? _rangeStart : _rangeEnd,
      firstDate: _rangeStart,
      lastDate: DateTime(2030, 12, 31),
      locale: const Locale('hu', 'HU'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _rangeEnd = _dateOnly(picked);
    });
  }

  Widget _buildDateRangeSection() {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isMultiDay)
          TextField(
            readOnly: true,
            controller: TextEditingController(text: _formatHuDate(_rangeStart)),
            decoration: InputDecoration(labelText: 'Dátum'),
            onTap: _pickStartDate,
          )
        else ...[
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: TextField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: _formatHuDate(_rangeStart),
                  ),
                  decoration: InputDecoration(labelText: 'Kezdő dátum'),
                  onTap: _pickStartDate,
                ),
              ),
              Expanded(
                child: TextField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: _formatHuDate(_rangeEnd),
                  ),
                  decoration: InputDecoration(labelText: 'Záró dátum'),
                  onTap: _pickEndDate,
                ),
              ),
            ],
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Többnapos esemény'),
          value: _isMultiDay,
          onChanged: (value) {
            setState(() {
              _isMultiDay = value;
              if (!value) {
                _rangeEnd = _rangeStart;
              }
            });
          },
        ),
      ],
    );
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final teamId = await UserService.getTeamId();
      final endForSave = _isMultiDay ? _rangeEnd : _rangeStart;
      final eventData = {
        'teamId': teamId,
        'date': Timestamp.fromDate(_rangeStart),
        'endDate': Timestamp.fromDate(endForSave),
        'type': _selectedType,
        'title': title,
        'description': description,
        'assignedEmployees': _assignedEmployees,
        'assignedProjects': _selectedProjectIds,
        'priority': _selectedPriority,
        'subtasks':
            _subtasks
                .map((subtask) {
                  final id = subtask['id'] as String;
                  final controller = _subtaskControllers[id];
                  return {
                    'title': controller?.text.trim() ?? '',
                    'status': subtask['status'] as String,
                  };
                })
                .where((subtask) => subtask['title'].toString().isNotEmpty)
                .toList(),
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

  void _showProjectSelectionModal() {
    final Set<String> selectedProjectIds = Set<String>.from(
      _selectedProjectIds,
    );
    String? selectedFilter = null; // null = "Összes"

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setModalState) {
              if (_isLoadingProjects) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              // Szűrjük a projekteket státusz alapján
              final filteredProjects =
                  selectedFilter == null
                      ? _projects
                      : _projects.where((project) {
                        return project['status'] == selectedFilter;
                      }).toList();

              return Container(
                padding: const EdgeInsets.all(24),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Projektek kiválasztása',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Szűrő OptionChip-ek
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 5,
                        children: [
                          FilterChip(
                            label: const Text('Összes'),
                            selected: selectedFilter == null,
                            onSelected: (bool selected) {
                              setModalState(() {
                                selectedFilter =
                                    selected ? null : selectedFilter;
                              });
                            },
                          ),
                          FilterChip(
                            label: const Text('Folyamatban'),
                            selected: selectedFilter == 'ongoing',
                            onSelected: (bool selected) {
                              setModalState(() {
                                selectedFilter = selected ? 'ongoing' : null;
                              });
                            },
                          ),
                          FilterChip(
                            label: const Text('Kész'),
                            selected: selectedFilter == 'done',
                            onSelected: (bool selected) {
                              setModalState(() {
                                selectedFilter = selected ? 'done' : null;
                              });
                            },
                          ),
                          FilterChip(
                            label: const Text('Karbantartás'),
                            selected: selectedFilter == 'maintenance',
                            onSelected: (bool selected) {
                              setModalState(() {
                                selectedFilter =
                                    selected ? 'maintenance' : null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child:
                          filteredProjects.isEmpty
                              ? Center(
                                child: Text(
                                  selectedFilter == null
                                      ? 'Nincs elérhető projekt.'
                                      : 'Nincs elérhető projekt ebben a kategóriában.',
                                ),
                              )
                              : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredProjects.length,
                                itemBuilder: (context, index) {
                                  final project = filteredProjects[index];
                                  final projectId = project['id'] as String;
                                  final isSelected = selectedProjectIds
                                      .contains(projectId);
                                  return CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    title: Text(project['name'] as String),
                                    value: isSelected,
                                    onChanged: (bool? value) {
                                      setModalState(() {
                                        if (value == true) {
                                          selectedProjectIds.add(projectId);
                                        } else {
                                          selectedProjectIds.remove(projectId);
                                        }
                                        setState(() {
                                          _selectedProjectIds =
                                              selectedProjectIds.toList();
                                        });
                                      });
                                    },
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  void _showAvailableEmployeesModal() {
    final initialIds =
        _assignedEmployees
            .where((tag) => _availableEmployees.any((emp) => emp['id'] == tag))
            .toSet();

    showEmployeeSelectionBottomSheet(
      context: context,
      availableEmployees: _availableEmployees,
      initialSelectedIds: initialIds,
      onSelectionChanged: (ids) {
        setState(() {
          _assignedEmployees.removeWhere((tag) {
            return _availableEmployees.any((emp) => emp['id'] == tag);
          });
          _assignedEmployees.addAll(ids);
        });
      },
    );
  }

  Widget _buildProjectSelector() {
    final selectedProjects =
        _projects.where((project) {
          return _selectedProjectIds.contains(project['id']);
        }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Projekt', style: Theme.of(context).textTheme.titleMedium),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _showProjectSelectionModal,
              icon:
                  _selectedProjectIds.isEmpty
                      ? const Icon(Icons.add, size: 20)
                      : null,
              label: Text(
                _selectedProjectIds.isEmpty ? 'Hozzárendelés' : 'Szerkesztés',
              ),
            ),
          ],
        ),
        if (selectedProjects.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  selectedProjects.map((project) {
                    final projectName = project['name'] as String;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(label: Text(projectName)),
                    );
                  }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Prioritás', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            style: ButtonStyle(
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              ),
            ),
            segments: List<ButtonSegment<int>>.generate(3, (int index) {
              switch (index) {
                case 0:
                  return ButtonSegment<int>(
                    value: index,
                    label: const Text('Normál'),
                  );
                case 1:
                  return ButtonSegment<int>(
                    value: index,
                    label: const Text('Fontos'),
                  );
                case 2:
                  return ButtonSegment<int>(
                    value: index,
                    label: const Text('Sürgős'),
                  );
                default:
                  return ButtonSegment<int>(value: index, label: Text(''));
              }
            }),
            selected: {_selectedPriority},
            onSelectionChanged: (Set<int> newSelection) {
              setState(() {
                switch (newSelection.first) {
                  case 0:
                    _selectedPriority = 0;
                    break;
                  case 1:
                    _selectedPriority = 1;
                    break;
                  case 2:
                    _selectedPriority = 2;
                    break;
                  default:
                    _selectedPriority = 1;
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubtasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Részfeladatok',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _showSubtaskSchemesSheet,
              child: const Text('Sémák'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_subtasks.isNotEmpty) ...[
          ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _subtasks.length,
            itemBuilder: (context, index) {
              final subtask = _subtasks[index];
              final id = subtask['id'] as String;
              final status = subtask['status'] as String;
              final isDone = status == 'done';
              final controller =
                  _subtaskControllers[id] ??= TextEditingController();

              return Dismissible(
                background: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.delete,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ],
                    ),
                  ),
                ),
                direction: DismissDirection.endToStart,
                key: Key(id),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Checkbox(
                    value: isDone,
                    onChanged: (bool? value) {
                      _toggleSubtaskStatus(index);
                    },
                  ),
                  title: TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Részfeladat címe',
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color:
                          isDone
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : null,
                    ),
                  ),
                ),
                onDismissed: (direction) {
                  _removeSubtask(index);
                },
              );
            },
          ),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Expanded(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _addSubtask,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Részfeladat'),
              ),
            ),
            if (_subtasks.isNotEmpty)
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isSaving ? null : _saveSubtaskScheme,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                  label: const Text('Mentés'),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.eventId != null ? 'Bejegyzés szerkesztése' : 'Új bejegyzés',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child:
                _isSaving || _isDeleting
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : FilledButton(
                      onPressed: _saveEvent,
                      child: const Text('Mentés'),
                    ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDateRangeSection(),
                  const SizedBox(height: 16),
                  TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Cím',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                    ),

                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Kérjük, adja meg a címet';
                      }
                      return null;
                    },
                  ),
                  const Divider(),
                  TextFormField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      hintText: 'Leírás',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                    ),
                    maxLines: 4,
                  ),
                  const Divider(),
                  _buildProjectSelector(),
                  const Divider(),
                  SelectedEmployeesSection(
                    availableEmployees: _availableEmployees,
                    assignedEmployeeIds: _assignedEmployees,
                    onEditPressed: _showAvailableEmployeesModal,
                  ),
                  const Divider(),
                  _buildPrioritySelector(),
                  const Divider(),
                  _buildSubtasksSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveSubtaskSchemeNameDialog extends StatefulWidget {
  const _SaveSubtaskSchemeNameDialog();

  @override
  State<_SaveSubtaskSchemeNameDialog> createState() =>
      _SaveSubtaskSchemeNameDialogState();
}

class _SaveSubtaskSchemeNameDialogState
    extends State<_SaveSubtaskSchemeNameDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Séma mentése'),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Séma neve',
          hintText: 'Add meg a séma megnevezését',
        ),
        onSubmitted: (_) {
          Navigator.pop(context, _nameController.text.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Mégse'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, _nameController.text.trim());
          },
          child: const Text('Mentés'),
        ),
      ],
    );
  }
}
