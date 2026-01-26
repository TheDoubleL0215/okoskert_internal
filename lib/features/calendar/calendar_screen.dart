import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:okoskert_internal/core/utils/services/employee_service.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:okoskert_internal/features/calendar/add_calendar_post_screen.dart';
import 'package:okoskert_internal/features/calendar/ui/event_details_bottom_sheet.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final Future<String?> _teamIdFuture;

  final ValueNotifier<DateTime?> _selectedDayNotifier = ValueNotifier(
    DateTime.now(),
  );

  final ValueNotifier<DateTime> _focusedDayNotifier = ValueNotifier(
    DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _teamIdFuture = UserService.getTeamId();
  }

  @override
  void dispose() {
    _selectedDayNotifier.dispose();
    _focusedDayNotifier.dispose();
    super.dispose();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  void _showAddEventBottomSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AddCalendarPostScreen(
              selectedDate: _selectedDayNotifier.value ?? DateTime.now(),
            ),
      ),
    );
  }

  void _showEventDetailsBottomSheet(Map<String, dynamic> event) {
    EventDetailsBottomSheet.show(context, event);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Naptár',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<String?>(
        future: _teamIdFuture,
        builder: (context, teamSnapshot) {
          if (teamSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final teamId = teamSnapshot.data;
          if (teamId == null || teamId.isEmpty) {
            return const Center(child: Text('Hiba: nincs teamId'));
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance
                    .collection('calendar')
                    .where('teamId', isEqualTo: teamId)
                    .snapshots(),
            builder: (context, snapshot) {
              final Map<String, List<Map<String, dynamic>>> eventSource = {};

              if (snapshot.hasData) {
                for (final doc in snapshot.data!.docs) {
                  final data = doc.data();
                  final date = data['date'] as Timestamp?;
                  if (date == null) continue;

                  final normalized = _normalizeDate(date.toDate());
                  final key =
                      '${normalized.year}-${normalized.month}-${normalized.day}';

                  eventSource.putIfAbsent(key, () => []);
                  eventSource[key]!.add({'id': doc.id, ...data});
                }
              }

              return Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    ValueListenableBuilder<DateTime?>(
                      valueListenable: _selectedDayNotifier,
                      builder: (context, selectedDay, _) {
                        return ValueListenableBuilder<DateTime>(
                          valueListenable: _focusedDayNotifier,
                          builder: (context, focusedDay, _) {
                            return _CalendarWidget(
                              eventSource: eventSource,
                              selectedDay: selectedDay,
                              focusedDay: focusedDay,
                              normalizeDate: _normalizeDate,
                              onDaySelected: (day, focused) {
                                _selectedDayNotifier.value = day;
                                _focusedDayNotifier.value = focused;
                              },
                            );
                          },
                        );
                      },
                    ),
                    const Divider(),
                    ValueListenableBuilder<DateTime?>(
                      valueListenable: _selectedDayNotifier,
                      builder: (context, selectedDay, _) {
                        final events =
                            selectedDay == null
                                ? <Map<String, dynamic>>[]
                                : eventSource['${selectedDay.year}-${selectedDay.month}-${selectedDay.day}'] ??
                                    [];

                        return _EventsListWidget(
                          selectedDay: selectedDay,
                          selectedDayEvents: events,
                          onEventTap: _showEventDetailsBottomSheet,
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventBottomSheet,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CalendarWidget extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> eventSource;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Function(DateTime, DateTime) onDaySelected;
  final DateTime Function(DateTime) normalizeDate;

  const _CalendarWidget({
    required this.eventSource,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.normalizeDate,
  });

  @override
  Widget build(BuildContext context) {
    return TableCalendar(
      locale: 'hu_HU',
      startingDayOfWeek: StartingDayOfWeek.monday,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      calendarStyle: CalendarStyle(
        todayTextStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
        todayDecoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1.0,
          ),
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        markerDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
      daysOfWeekVisible: false,
      firstDay: DateTime.utc(2010, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: focusedDay,
      selectedDayPredicate: (day) => isSameDay(selectedDay, day),
      onDaySelected: onDaySelected,
      eventLoader: (day) {
        final d = normalizeDate(day);
        return eventSource['${d.year}-${d.month}-${d.day}'] ?? [];
      },
    );
  }
}

class _EventsListWidget extends StatefulWidget {
  final DateTime? selectedDay;
  final List<Map<String, dynamic>> selectedDayEvents;
  final Function(Map<String, dynamic>) onEventTap;

  const _EventsListWidget({
    required this.selectedDay,
    required this.selectedDayEvents,
    required this.onEventTap,
  });

  @override
  State<_EventsListWidget> createState() => _EventsListWidgetState();
}

class _EventsListWidgetState extends State<_EventsListWidget> {
  List<Map<String, dynamic>> _availableEmployees = [];
  bool _isLoadingEmployees = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await EmployeeService.getEmployees();
      if (mounted) {
        setState(() {
          _availableEmployees = employees;
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEmployees = false;
        });
      }
    }
  }

  ColorScheme schemeForPriority(BuildContext context, int priority) {
    final brightness = Theme.of(context).brightness;

    ColorScheme fromSeed(Color seed) =>
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

    return switch (priority) {
      1 => fromSeed(Colors.yellow),
      2 => fromSeed(Colors.red),
      _ => Theme.of(context).colorScheme, // default green
    };
  }

  Widget _buildEmployeeAvatars(List<String> employeeIds) {
    if (_isLoadingEmployees || _availableEmployees.isEmpty) {
      return const SizedBox.shrink();
    }

    final employees =
        _availableEmployees.where((emp) {
          return employeeIds.contains(emp['id']);
        }).toList();

    if (employees.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxDisplayedEmployees = 2;

    final hasMore = employees.length > maxDisplayedEmployees;
    final displayEmployees = employees.take(maxDisplayedEmployees).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children:
          displayEmployees.map((employee) {
            final employeeName =
                (employee['name'] as String? ?? 'Névtelen').trim();
            final firstLetter =
                employeeName.isNotEmpty ? employeeName[0].toUpperCase() : '?';
            return Padding(
              padding: const EdgeInsets.only(left: 4),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  firstLetter,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            );
          }).toList() +
          (hasMore
              ? [
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text('+${employees.length - maxDisplayedEmployees}'),
                ),
              ]
              : []),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedDay == null) {
      return const Expanded(
        child: Center(child: Text('Válasszon ki egy napot')),
      );
    }

    if (widget.selectedDayEvents.isEmpty) {
      return const Expanded(
        child: Center(child: Text('Nincs bejegyzés erre a napra')),
      );
    }

    return Expanded(
      child: ListView.separated(
        itemCount: widget.selectedDayEvents.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final event = widget.selectedDayEvents[index];
          final assignedEmployees =
              (event['assignedEmployees'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          final scheme = schemeForPriority(context, event['priority']);
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: switch (event['priority']) {
                0 => Icon(LucideIcons.calendar, color: scheme.primary),
                1 => Icon(LucideIcons.flag, color: scheme.primary),
                2 => Icon(LucideIcons.siren, color: scheme.primary),
                _ => Icon(Icons.event, color: scheme.onPrimary),
              },
            ),

            title: Text(event['title'] ?? ''),
            subtitle:
                (event['description'] != null &&
                        (event['description'] as String).trim().isNotEmpty)
                    ? Text(
                      event['description'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                    : null,
            trailing: _buildEmployeeAvatars(assignedEmployees),
            onTap: () => widget.onEventTap(event),
          );
        },
      ),
    );
  }
}
