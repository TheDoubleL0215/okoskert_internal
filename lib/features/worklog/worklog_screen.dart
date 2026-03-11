import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okoskert_internal/app/workspace_provider.dart';
import 'package:okoskert_internal/core/utils/services/employee_service.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:okoskert_internal/features/worklog/filtering/multi_select_filter_sheet.dart';
import 'package:okoskert_internal/features/worklog/models/worklog_view_item.dart';
import 'package:okoskert_internal/features/worklog/services/worklog_stream.dart'
    as _worklogService;
import 'package:okoskert_internal/features/worklog/widgets/worklog_entry_tile.dart';
import 'package:provider/provider.dart';

class WorklogScreen extends StatefulWidget {
  const WorklogScreen({super.key});

  @override
  State<WorklogScreen> createState() => _WorklogScreenState();
}

class _WorklogScreenState extends State<WorklogScreen> {
  final Set<String> _selectedProjectIds = {};
  final Set<String> _selectedEmployeeIds = {};
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  bool get _hasActiveFilters =>
      _selectedProjectIds.isNotEmpty ||
      _selectedEmployeeIds.isNotEmpty ||
      _filterStartDate != null ||
      _filterEndDate != null;

  /// Szűri a listát kollégák és projektek alapján (id-k szerint).
  List<WorklogViewItem> _filterByColleaguesAndProjects(
    List<WorklogViewItem> items,
  ) {
    var result = items;
    if (_selectedEmployeeIds.isNotEmpty) {
      result =
          result
              .where((log) => _selectedEmployeeIds.contains(log.employeeId))
              .toList();
    }
    if (_selectedProjectIds.isNotEmpty) {
      result =
          result
              .where(
                (log) =>
                    log.projectId != null &&
                    _selectedProjectIds.contains(log.projectId),
              )
              .toList();
    }
    return result;
  }

  /// Szűri a listát a kiválasztott dátumtartományra (nap szinten).
  List<WorklogViewItem> _filterByDateRange(List<WorklogViewItem> items) {
    if (_filterStartDate == null && _filterEndDate == null) return items;
    return items.where((log) {
      final day = DateTime(log.date.year, log.date.month, log.date.day);
      if (_filterStartDate != null) {
        final start = DateTime(
          _filterStartDate!.year,
          _filterStartDate!.month,
          _filterStartDate!.day,
        );
        if (day.isBefore(start)) return false;
      }
      if (_filterEndDate != null) {
        final end = DateTime(
          _filterEndDate!.year,
          _filterEndDate!.month,
          _filterEndDate!.day,
        );
        if (day.isAfter(end)) return false;
      }
      return true;
    }).toList();
  }

  Widget _buildFilterChips(BuildContext context, String? teamId) {
    String dateLabel() {
      if (_filterStartDate == null && _filterEndDate == null)
        return 'Dátumtartomány';
      if (_filterStartDate != null && _filterEndDate != null) {
        return '${_formatDate(_filterStartDate!)} – ${_formatDate(_filterEndDate!)}';
      }
      if (_filterStartDate != null)
        return 'From ${_formatDate(_filterStartDate!)}';
      return 'Until ${_formatDate(_filterEndDate!)}';
    }

    String colleagueLabel() {
      if (_selectedEmployeeIds.isEmpty) return 'Kollégák';
      return 'Kollégák (${_selectedEmployeeIds.length})';
    }

    String projectLabel() {
      if (_selectedProjectIds.isEmpty) return 'Projektek';
      return 'Projektek (${_selectedProjectIds.length})';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            children: [
              FilterChip(
                label: Text(dateLabel()),
                selected: _filterStartDate != null || _filterEndDate != null,
                onSelected: (_) async {
                  final now = DateTime.now();
                  final start =
                      _filterStartDate ??
                      now.subtract(const Duration(days: 30));
                  final end = _filterEndDate ?? now;
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(now.year + 1),
                    initialDateRange: DateTimeRange(start: start, end: end),
                  );
                  if (picked != null) {
                    setState(() {
                      _filterStartDate = picked.start;
                      _filterEndDate = picked.end;
                    });
                  }
                },
              ),
              FilterChip(
                label: Text(colleagueLabel()),
                selected: _selectedEmployeeIds.isNotEmpty,
                onSelected: (_) => _showColleagueFilterSheet(context),
              ),
              FilterChip(
                label: Text(projectLabel()),
                selected: _selectedProjectIds.isNotEmpty,
                onSelected:
                    teamId != null && teamId.isNotEmpty
                        ? (_) => _showProjectFilterSheet(context, teamId)
                        : null,
              ),
            ],
          ),
          if (_hasActiveFilters)
            Padding(
              padding: const EdgeInsets.only(left: 0, bottom: 8, top: 4),
              child: TextButton(
                onPressed:
                    () => setState(() {
                      _filterStartDate = null;
                      _filterEndDate = null;
                      _selectedEmployeeIds.clear();
                      _selectedProjectIds.clear();
                    }),
                child: const Text('Szűrők törlése'),
              ),
            ),
        ],
      ),
    );
  }

  void _showColleagueFilterSheet(BuildContext context) {
    showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => MultiSelectFilterSheet(
            title: 'Kollégák szűrése',
            future: EmployeeService.getEmployees().then(
              (list) =>
                  list
                      .map(
                        (e) => {
                          'id': e['id'] as String,
                          'label':
                              ((e['name'] ?? e['email'] ?? e['id']) ?? '')
                                  .toString(),
                        },
                      )
                      .toList(),
            ),
            selectedIds: _selectedEmployeeIds,
          ),
    ).then((result) {
      if (result != null) {
        setState(() {
          _selectedEmployeeIds
            ..clear()
            ..addAll(result);
        });
      }
    });
  }

  void _showProjectFilterSheet(BuildContext context, String teamId) {
    showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => MultiSelectFilterSheet(
            title: 'Projektek szűrése',
            future: FirebaseFirestore.instance
                .collection('projects')
                .where('teamId', isEqualTo: teamId)
                .get()
                .then(
                  (snap) =>
                      snap.docs
                          .map(
                            (d) => {
                              'id': d.id,
                              'label':
                                  (d.data()['projectName'] ?? d.id) as String,
                            },
                          )
                          .toList(),
                ),
            selectedIds: _selectedProjectIds,
          ),
    ).then((result) {
      if (result != null) {
        setState(() {
          _selectedProjectIds
            ..clear()
            ..addAll(result);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkspaceProvider>();
    final workspaceRef = wp.workspaceRef;

    if (wp.isLoading || workspaceRef == null) {
      if (wp.error != null && !wp.isLoading) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Munkanapló',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Hiba történt a workspace betöltésekor: ${wp.error}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }
      if (workspaceRef == null && !wp.isLoading) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Munkanapló',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: const Center(
            child: Text('Nem található workspace a jelenlegi csapathoz.'),
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Munkanapló',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Munkanapló',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder(
        future: UserService.getTeamId(),
        builder: (context, teamIdSnapshot) {
          if (teamIdSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final teamId = teamIdSnapshot.data;
          if (teamId == null || teamId.isEmpty) {
            return const Center(child: Text('Nem található teamId'));
          }
          return StreamBuilder<List<WorklogViewItem>>(
            stream: _worklogService.getHydratedWorklogs(workspaceRef, teamId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allLogs = snapshot.data ?? [];
              final byDate = _filterByDateRange(allLogs);
              final logs = _filterByColleaguesAndProjects(byDate);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterChips(context, teamId),
                  Expanded(
                    child:
                        logs.isEmpty
                            ? Center(
                              child: Text(
                                _hasActiveFilters
                                    ? 'Nincs találat a kiválasztott szűrők alapján.'
                                    : 'Még nincsenek munkanapló bejegyzések.',
                              ),
                            )
                            : ListView.builder(
                              itemCount: logs.length,
                              itemBuilder: (context, index) {
                                final log = logs[index];
                                return WorklogEntryTile(
                                  employeeName: log.employeeName,
                                  startTime: log.startTime,
                                  endTime: log.endTime,
                                  breakMinutes: log.breakMinutes,
                                  description: log.description,
                                  projectName:
                                      log.projectName != null &&
                                              log.projectName!.isNotEmpty
                                          ? log.projectName
                                          : null,
                                  showDivider: true,
                                );
                              },
                            ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}.';
  }
}
