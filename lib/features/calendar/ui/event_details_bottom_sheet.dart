import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/core/utils/services/employee_service.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:okoskert_internal/features/calendar/add_calendar_post_screen.dart';
import 'package:okoskert_internal/features/projects/project_details/project_details_screen.dart';

class EventDetailsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> event;

  const EventDetailsBottomSheet({super.key, required this.event});

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> event,
  ) async {
    final date = event['date'] as Timestamp?;
    final eventDate = date?.toDate();

    final assignedEmployees =
        (event['assignedEmployees'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final assignedProjects =
        (event['assignedProjects'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    // Betöltjük a munkatársak neveit
    List<Map<String, dynamic>> employees = [];
    try {
      employees = await EmployeeService.getEmployees();
    } catch (e) {
      debugPrint('Hiba a munkatársak betöltésekor: $e');
    }

    // Betöltjük a projektek neveit
    List<Map<String, dynamic>> projects = [];
    try {
      final teamId = await UserService.getTeamId();
      if (teamId != null && teamId.isNotEmpty) {
        final snapshot =
            await FirebaseFirestore.instance
                .collection('projects')
                .where('teamId', isEqualTo: teamId)
                .get();
        projects =
            snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'name': data['projectName'] as String? ?? 'Névtelen projekt',
              };
            }).toList();
      }
    } catch (e) {
      debugPrint('Hiba a projektek betöltésekor: $e');
    }

    // Szűrjük a releváns munkatársakat és projekteket
    final relevantEmployees =
        employees
            .where((emp) => assignedEmployees.contains(emp['id']))
            .toList();

    final relevantProjects =
        projects
            .where((proj) => assignedProjects.contains(proj['id']))
            .toList();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => _EventDetailsContent(
            event: event,
            eventDate: eventDate,
            relevantEmployees: relevantEmployees,
            relevantProjects: relevantProjects,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This widget is not meant to be built directly
    // Use EventDetailsBottomSheet.show() instead
    throw UnimplementedError(
      'Use EventDetailsBottomSheet.show() to display the bottom sheet',
    );
  }
}

class _EventDetailsContent extends StatefulWidget {
  final Map<String, dynamic> event;
  final DateTime? eventDate;
  final List<Map<String, dynamic>> relevantEmployees;
  final List<Map<String, dynamic>> relevantProjects;

  const _EventDetailsContent({
    required this.event,
    this.eventDate,
    required this.relevantEmployees,
    required this.relevantProjects,
  });

  @override
  State<_EventDetailsContent> createState() => _EventDetailsContentState();
}

class _EventDetailsContentState extends State<_EventDetailsContent> {
  late List<Map<String, dynamic>> _subtasks;

  @override
  void initState() {
    super.initState();
    _subtasks =
        (widget.event['subtasks'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
  }

  Widget _buildSubtasksList(BuildContext context) {
    if (_subtasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          _subtasks.asMap().entries.map((entry) {
            final index = entry.key;
            final subtask = entry.value;
            final title = subtask['title'] as String? ?? '';
            final status = subtask['status'] as String? ?? 'ongoing';
            final isDone = status == 'done';

            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                title,
                style: TextStyle(
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  color:
                      isDone
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : null,
                ),
              ),
              value: isDone,
              onChanged: (bool? value) async {
                if (value == null || widget.event['id'] == null) return;

                final newStatus = value ? 'done' : 'ongoing';

                // Frissítjük a lokális állapotot
                setState(() {
                  if (index < _subtasks.length) {
                    _subtasks[index]['status'] = newStatus;
                  }
                });

                // Frissítjük a Firestore-ban
                try {
                  await FirebaseFirestore.instance
                      .collection('calendar')
                      .doc(widget.event['id'])
                      .update({'subtasks': _subtasks});
                } catch (error) {
                  // Ha hiba van, visszaállítjuk az állapotot
                  setState(() {
                    if (index < _subtasks.length) {
                      _subtasks[index]['status'] = isDone ? 'done' : 'ongoing';
                    }
                  });

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Hiba történt a frissítéskor: $error'),
                    ),
                  );
                }
              },
            );
          }).toList(),
    );
  }

  void _navigateToEdit(BuildContext context) {
    final date = widget.event['date'] as Timestamp?;
    final eventDate = date?.toDate();
    final selectedDate = eventDate ?? DateTime.now();

    final assignedEmployees =
        (widget.event['assignedEmployees'] as List?)
            ?.map((e) => e.toString())
            .toList();
    final assignedProjects =
        (widget.event['assignedProjects'] as List?)
            ?.map((e) => e.toString())
            .toList();

    // Használjuk a frissített _subtasks state-et, nem a widget.event['subtasks']-ot
    final subtasksToPass =
        _subtasks.isNotEmpty
            ? List<Map<String, dynamic>>.from(_subtasks)
            : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AddCalendarPostScreen(
              initialSubtasks: subtasksToPass,
              selectedDate: selectedDate,
              eventId: widget.event['id'],
              initialType: widget.event['type'],
              initialDescription: widget.event['description'],
              initialTitle: widget.event['title'],
              initialAssignedEmployees: assignedEmployees,
              initialAssignedProjects: assignedProjects,
              initialPriority: widget.event['priority'],
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Future<void> _deleteEvent() async {
      if (widget.event['id'] == null) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Bejegyzés törlése'),
              content: const Text(
                'Biztosan törölni szeretnéd ezt a bejegyzést?',
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

      if (confirmed != true) return;

      try {
        await FirebaseFirestore.instance
            .collection('calendar')
            .doc(widget.event['id'])
            .delete();

        if (!context.mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bejegyzés sikeresen törölve')),
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba történt a törléskor: $error')),
        );
      }
    }

    void handleClick(String value) {
      switch (value) {
        case 'Törlés':
          _deleteEvent();
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                  widget.event['title'] ?? 'Névtelen bejegyzés',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                position: PopupMenuPosition.under,
                onSelected: handleClick,
                itemBuilder: (BuildContext context) {
                  return {'Törlés'}.map((String choice) {
                    return PopupMenuItem<String>(
                      value: choice,
                      child: Row(
                        children: [
                          Icon(Icons.delete),
                          const SizedBox(width: 8),
                          Text(choice),
                        ],
                      ),
                    );
                  }).toList();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.eventDate != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.eventDate!.year}. ${widget.eventDate!.month.toString().padLeft(2, '0')}. ${widget.eventDate!.day.toString().padLeft(2, '0')}.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.event['description'] != null &&
                      widget.event['description'].toString().isNotEmpty) ...[
                    Text(
                      'Leírás',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.event['description'] ?? '',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (widget.relevantEmployees.isNotEmpty) ...[
                    Text(
                      'Hozzárendelt munkatársak',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          widget.relevantEmployees.map((employee) {
                            final employeeName =
                                (employee['name'] as String? ?? 'Névtelen')
                                    .trim();
                            final firstLetter =
                                employeeName.isNotEmpty
                                    ? employeeName[0].toUpperCase()
                                    : '?';
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor:
                                      Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                  child: Text(
                                    firstLetter,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  employeeName,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (widget.relevantProjects.isNotEmpty) ...[
                    Text(
                      'Hozzárendelt projektek',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          widget.relevantProjects.map((project) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => ProjectDetailsScreen(
                                          projectId: project['id'],
                                          projectName:
                                              project['name'] as String,
                                        ),
                                  ),
                                );
                              },
                              child: Chip(
                                label: Text(project['name'] as String),
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_subtasks.isNotEmpty) ...[
                    Text(
                      'Részfeladatok',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSubtasksList(context),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: TextButton.styleFrom(padding: const EdgeInsets.all(16)),
                onPressed: () => Navigator.pop(context),
                child: const Text('Bezárás'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToEdit(context);
                },
                icon: const Icon(Icons.edit),
                label: const Text('Szerkesztés'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
