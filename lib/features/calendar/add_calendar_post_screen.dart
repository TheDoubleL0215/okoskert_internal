import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/core/utils/services/employee_service.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';

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

  @override
  void initState() {
    super.initState();
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
      final eventData = {
        'teamId': teamId,
        'date': Timestamp.fromDate(
          DateTime(
            widget.selectedDate.year,
            widget.selectedDate.month,
            widget.selectedDate.day,
          ),
        ),
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
    final Set<String> selectedEmployeeIds = Set<String>.from(
      _assignedEmployees.where((tag) {
        // Ellenőrizzük, hogy a tag egy létező employee ID-e
        return _availableEmployees.any((emp) => emp['id'] == tag);
      }),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Container(
                  padding: const EdgeInsets.all(24),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Munkatársak kiválasztása',
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
                      Expanded(
                        child:
                            _availableEmployees.isEmpty
                                ? const Center(
                                  child: Text('Nincs elérhető munkatárs.'),
                                )
                                : GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio: 0.75,
                                      ),
                                  itemCount: _availableEmployees.length,
                                  itemBuilder: (context, index) {
                                    final employee = _availableEmployees[index];
                                    final employeeId = employee['id'] as String;
                                    final employeeName =
                                        (employee['name'] as String? ??
                                                'Névtelen')
                                            .trim();
                                    final firstLetter =
                                        employeeName.isNotEmpty
                                            ? employeeName[0].toUpperCase()
                                            : '?';
                                    final isSelected = selectedEmployeeIds
                                        .contains(employeeId);

                                    return GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          if (isSelected) {
                                            selectedEmployeeIds.remove(
                                              employeeId,
                                            );
                                          } else {
                                            selectedEmployeeIds.add(employeeId);
                                          }
                                          setState(() {
                                            // Eltávolítjuk azokat a tag-eket, amelyek employee ID-k voltak
                                            _assignedEmployees.removeWhere((
                                              tag,
                                            ) {
                                              return _availableEmployees.any(
                                                (emp) => emp['id'] == tag,
                                              );
                                            });
                                            // Hozzáadjuk a kiválasztott employee ID-kat
                                            _assignedEmployees.addAll(
                                              selectedEmployeeIds,
                                            );
                                          });
                                        });
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              CircleAvatar(
                                                radius: 40,
                                                backgroundColor:
                                                    isSelected
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .primaryContainer
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .surfaceVariant,
                                                child: Text(
                                                  firstLetter,
                                                  style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        isSelected
                                                            ? Theme.of(context)
                                                                .colorScheme
                                                                .onPrimaryContainer
                                                            : Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                              if (isSelected)
                                                Positioned(
                                                  right: -2,
                                                  bottom: -2,
                                                  child: CircleAvatar(
                                                    backgroundColor:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                    radius: 10,
                                                    child: Icon(
                                                      Icons.check,
                                                      size: 16,
                                                      color:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .onPrimary,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Flexible(
                                            child: Text(
                                              employeeName,
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildSelectedEmployees() {
    final selectedEmployees =
        _availableEmployees.where((emp) {
          return _assignedEmployees.contains(emp['id']);
        }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Munkatársak', style: Theme.of(context).textTheme.titleMedium),
            FilledButton.tonalIcon(
              onPressed: _showAvailableEmployeesModal,
              icon:
                  _assignedEmployees.isEmpty
                      ? const Icon(Icons.add, size: 20)
                      : null,
              label: Text(
                _assignedEmployees.isEmpty ? 'Hozzárendelés' : 'Szerkesztés',
              ),
            ),
          ],
        ),
        if (selectedEmployees.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    selectedEmployees.map((employee) {
                      final employeeName =
                          (employee['name'] as String? ?? 'Névtelen').trim();
                      final firstLetter =
                          employeeName.isNotEmpty
                              ? employeeName[0].toUpperCase()
                              : '?';
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                              child: Text(
                                firstLetter,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
        ],
      ],
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
        Text('Részfeladatok', style: Theme.of(context).textTheme.titleMedium),
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
        TextButton.icon(
          onPressed: _addSubtask,
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Részfeladat hozzáadása'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
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
                  _buildSelectedEmployees(),
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
