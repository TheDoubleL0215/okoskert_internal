import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:okoskert_internal/app/workspace_provider.dart';
import 'package:okoskert_internal/core/utils/services/employee_service.dart';
import 'package:okoskert_internal/core/utils/services/project_service.dart';
import 'package:okoskert_internal/features/worklog/view/create_new_worklog_screen.dart';
import 'package:okoskert_internal/shared/widgets/multi_select_filter_sheet.dart';
import 'package:okoskert_internal/features/worklog/models/worklog_item_model.dart';
import 'package:okoskert_internal/features/worklog/viewmodel/worklog_view_model.dart';
import 'package:okoskert_internal/shared/widgets/worklog_entry_tile.dart';
import 'package:provider/provider.dart';

class WorklogScreen extends StatelessWidget {
  const WorklogScreen({super.key});

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

    return ChangeNotifierProvider<WorklogViewModel>(
      create: (_) => WorklogViewModel(workspaceProvider: wp),
      child: const _WorklogView(),
    );
  }
}

class _WorklogView extends StatelessWidget {
  const _WorklogView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WorklogViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Munkanapló',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Builder(
        builder: (context) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(viewModel.error!, textAlign: TextAlign.center),
              ),
            );
          }

          final teamId = viewModel.teamId;
          final grouped = viewModel.logsGroupedByDate;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FilterChips(teamId: teamId),
              Expanded(
                child:
                    grouped.isEmpty
                        ? Center(
                          child: Text(
                            viewModel.hasActiveFilters
                                ? 'Nincs találat a kiválasztott szűrők alapján.'
                                : 'Még nincsenek munkanapló bejegyzések.',
                          ),
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 72),
                          separatorBuilder:
                              (_, __) => const Divider(thickness: 1, height: 0),
                          itemCount: _groupedItemCount(grouped),
                          itemBuilder: (context, index) {
                            final item = _itemAtGroupedIndex(grouped, index);
                            if (item == null) return const SizedBox.shrink();
                            if (item.isHeader) {
                              return _DateSectionHeader(
                                date: item.date!,
                                label: viewModel.formatDateForSectionHeader(
                                  item.date!,
                                ),
                              );
                            }
                            return WorklogEntryTile(
                              item: item.log!,
                              onTap:
                                  () => viewModel.showEditWorklogBottomSheet(
                                    context,
                                    item.log!,
                                  ),
                            );
                          },
                        ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        label: const Text(
          'Új bejegyzés hozzáadása',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateNewWorklogScreen(),
              ),
            ),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

int _groupedItemCount(
  List<MapEntry<DateTime, List<WorklogItemModel>>> grouped,
) {
  var count = 0;
  for (final entry in grouped) {
    count += 1; // section header
    count += entry.value.length;
  }
  return count;
}

_GroupedListItem? _itemAtGroupedIndex(
  List<MapEntry<DateTime, List<WorklogItemModel>>> grouped,
  int index,
) {
  var i = 0;
  for (final entry in grouped) {
    if (index == i) {
      return _GroupedListItem(isHeader: true, date: entry.key);
    }
    i++;
    for (final log in entry.value) {
      if (index == i) return _GroupedListItem(isHeader: false, log: log);
      i++;
    }
  }
  return null;
}

class _GroupedListItem {
  const _GroupedListItem({this.isHeader = false, this.date, this.log});

  final bool isHeader;
  final DateTime? date;
  final WorklogItemModel? log;
}

class _DateSectionHeader extends StatelessWidget {
  const _DateSectionHeader({required this.date, required this.label});

  final DateTime date;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.teamId});

  final String? teamId;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WorklogViewModel>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 8,
              children: [
                FilterChip(
                  label: Text(viewModel.dateFilterLabel),
                  selected:
                      viewModel.filterStartDate != null ||
                      viewModel.filterEndDate != null,
                  onSelected: (_) async {
                    final now = DateTime.now();
                    final start =
                        viewModel.filterStartDate ??
                        now.subtract(const Duration(days: 30));
                    final end = viewModel.filterEndDate ?? now;
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(now.year + 1),
                      initialDateRange: DateTimeRange(start: start, end: end),
                    );
                    if (picked != null) {
                      viewModel.setDateRange(picked.start, picked.end);
                    }
                  },
                ),
                FilterChip(
                  label: Text(viewModel.colleagueFilterLabel),
                  selected: viewModel.selectedEmployeeIds.isNotEmpty,
                  onSelected: (_) => _showColleagueFilterSheet(context),
                ),
                FilterChip(
                  label: Text(viewModel.projectFilterLabel),
                  selected: viewModel.selectedProjectIds.isNotEmpty,
                  onSelected:
                      teamId != null && teamId!.isNotEmpty
                          ? (_) => _showProjectFilterSheet(context, teamId!)
                          : null,
                ),
              ],
            ),
          ),
          if (viewModel.hasActiveFilters)
            Padding(
              padding: const EdgeInsets.only(left: 0, bottom: 8, top: 4),
              child: TextButton.icon(
                icon: const Icon(LucideIcons.funnelX),
                onPressed: viewModel.clearFilters,
                label: const Text('Szűrők törlése'),
              ),
            ),
        ],
      ),
    );
  }

  void _showColleagueFilterSheet(BuildContext context) {
    final viewModel = context.read<WorklogViewModel>();

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
            selectedIds: viewModel.selectedEmployeeIds,
          ),
    ).then((result) {
      if (result != null) {
        viewModel.setSelectedEmployeeIds(result);
      }
    });
  }

  void _showProjectFilterSheet(BuildContext context, String teamId) {
    final viewModel = context.read<WorklogViewModel>();

    showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => MultiSelectFilterSheet(
            title: 'Projektek szűrése',
            future: ProjectService.getProjectsByTeamId(teamId).then(
              (list) =>
                  list
                      .map(
                        (p) => {
                          'id': p['id'] as String,
                          'label':
                              (p['projectName'] ?? p['id'] ?? '') as String,
                        },
                      )
                      .toList(),
            ),
            selectedIds: viewModel.selectedProjectIds,
          ),
    ).then((result) {
      if (result != null) {
        viewModel.setSelectedProjectIds(result);
      }
    });
  }
}
