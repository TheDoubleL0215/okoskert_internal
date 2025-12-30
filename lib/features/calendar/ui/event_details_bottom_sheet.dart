import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/data/services/get_employees.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:okoskert_internal/features/projects/project_details/project_details_screen.dart';

class EventDetailsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback? onEdit;

  const EventDetailsBottomSheet({super.key, required this.event, this.onEdit});

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> event, {
    VoidCallback? onEdit,
  }) async {
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
            onEdit: onEdit,
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

class _EventDetailsContent extends StatelessWidget {
  final Map<String, dynamic> event;
  final DateTime? eventDate;
  final List<Map<String, dynamic>> relevantEmployees;
  final List<Map<String, dynamic>> relevantProjects;
  final VoidCallback? onEdit;

  const _EventDetailsContent({
    required this.event,
    this.eventDate,
    required this.relevantEmployees,
    required this.relevantProjects,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    Future<void> _deleteEvent() async {
      if (event['id'] == null) return;

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
            .doc(event['id'])
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
                  event['title'] ?? 'Névtelen bejegyzés',
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
          if (eventDate != null) ...[
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${eventDate!.year}. ${eventDate!.month.toString().padLeft(2, '0')}. ${eventDate!.day.toString().padLeft(2, '0')}.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (event['description'] != null &&
              event['description'].toString().isNotEmpty) ...[
            Text(
              'Leírás',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              event['description'] ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
          ],
          if (relevantEmployees.isNotEmpty) ...[
            Text(
              'Hozzárendelt munkatársak',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  relevantEmployees.map((employee) {
                    final employeeName =
                        (employee['name'] as String? ?? 'Névtelen').trim();
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
                              Theme.of(context).colorScheme.primaryContainer,
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
          if (relevantProjects.isNotEmpty) ...[
            Text(
              'Hozzárendelt projektek',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  relevantProjects.map((project) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ProjectDetailsScreen(
                                  projectId: project['id'],
                                  projectName: project['name'] as String,
                                ),
                          ),
                        );
                      },
                      child: Chip(label: Text(project['name'] as String)),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Bezárás'),
              ),
              if (onEdit != null) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onEdit?.call();
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Szerkesztés'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
