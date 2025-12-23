import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:okoskert_internal/features/calendar/ui/add_calendar_event_bottom_sheet.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  void _showAddEventBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => AddCalendarEventBottomSheet(
            selectedDate: _selectedDay ?? DateTime.now(),
          ),
    );
  }

  void _showEditEventBottomSheet(Map<String, dynamic> event) {
    final eventId = event['id'] as String?;
    final type = event['type'] as String?;
    final description = event['description'] as String?;
    final date = event['date'] as Timestamp?;
    final selectedDate =
        date != null ? date.toDate() : (_selectedDay ?? DateTime.now());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => AddCalendarEventBottomSheet(
            selectedDate: selectedDate,
            eventId: eventId,
            initialType: type,
            initialDescription: description,
          ),
    );
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
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
        future: UserService.getTeamId(),
        builder: (context, teamIdSnapshot) {
          if (teamIdSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final teamId = teamIdSnapshot.data;
          if (teamId == null || teamId.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Hiba: nem található teamId',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance
                    .collection('calendar')
                    .where('teamId', isEqualTo: teamId)
                    .snapshots(),
            builder: (context, snapshot) {
              // EventSource map létrehozása - string kulcsokkal a dátumokhoz
              Map<String, List<Map<String, dynamic>>> eventSource = {};

              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data();
                  final date = data['date'] as Timestamp?;
                  if (date != null) {
                    final normalizedDate = _normalizeDate(date.toDate());
                    final dateKey =
                        '${normalizedDate.year}-${normalizedDate.month}-${normalizedDate.day}';
                    if (!eventSource.containsKey(dateKey)) {
                      eventSource[dateKey] = [];
                    }
                    eventSource[dateKey]!.add({'id': doc.id, ...data});
                  }
                }
              }

              // Kiválasztott nap bejegyzései
              final selectedDayEvents =
                  _selectedDay != null
                      ? eventSource['${_selectedDay!.year}-${_selectedDay!.month}-${_selectedDay!.day}'] ??
                          []
                      : <Map<String, dynamic>>[];

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    TableCalendar(
                      locale: 'hu_HU',
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                      ),
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.0,
                          ),
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: const TextStyle(color: Colors.black),
                        selectedDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        selectedTextStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          if (events.isNotEmpty) {
                            return Positioned(
                              bottom: -1,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  events.length > 3 ? 3 : events.length,
                                  (index) => Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      eventLoader: (day) {
                        final normalizedDay = _normalizeDate(day);
                        final dateKey =
                            '${normalizedDay.year}-${normalizedDay.month}-${normalizedDay.day}';
                        return eventSource[dateKey] ?? [];
                      },
                      daysOfWeekVisible: false,
                      firstDay: DateTime.utc(2010, 10, 16),
                      lastDay: DateTime.utc(2030, 3, 14),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) {
                        return isSameDay(_selectedDay, day);
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                    ),
                    const Divider(),
                    Expanded(
                      child:
                          _selectedDay == null
                              ? const Center(
                                child: Text('Válasszon ki egy napot'),
                              )
                              : selectedDayEvents.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 48,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Nincsenek bejegyzések erre a napra',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                itemCount: selectedDayEvents.length,
                                itemBuilder: (context, index) {
                                  final event = selectedDayEvents[index];
                                  final type = event['type'] as String? ?? '';
                                  final description =
                                      event['description'] as String? ?? '';

                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color:
                                              type == 'Jegyzet'
                                                  ? Theme.of(
                                                    context,
                                                  ).colorScheme.primaryContainer
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .secondaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          type == 'Jegyzet'
                                              ? Icons.note
                                              : Icons.shopping_cart,
                                          color:
                                              type == 'Jegyzet'
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .onPrimaryContainer
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSecondaryContainer,
                                        ),
                                      ),
                                      title: Text(
                                        type,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        description,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap:
                                          () =>
                                              _showEditEventBottomSheet(event),
                                    ),
                                  );
                                },
                              ),
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
