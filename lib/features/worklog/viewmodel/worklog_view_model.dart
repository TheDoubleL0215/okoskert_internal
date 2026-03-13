import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/app/workspace_provider.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/project_data_collegues/ColleagueWorklogEntryEdit.dart';
import 'package:okoskert_internal/features/worklog/models/worklog_item_model.dart';
import 'package:okoskert_internal/features/worklog/services/worklog_stream.dart'
    as _worklogService;

/// ViewModel a munkanapló képernyőhöz.
///
/// Feladata:
/// - teamId betöltése az aktuális felhasználóhoz
/// - a workspace-hez tartozó worklog stream figyelése
/// - szűrők (dátum, kollégák, projektek) kezelése
/// - szűrt lista előállítása
class WorklogViewModel extends ChangeNotifier {
  WorklogViewModel({required WorkspaceProvider workspaceProvider})
    : _workspaceProvider = workspaceProvider {
    _init();
  }

  final WorkspaceProvider _workspaceProvider;

  String? _teamId;
  String? _error;
  bool _isLoading = false;

  // Nyers, szűretlen bejegyzések a streamből.
  List<WorklogItemModel> _allLogs = <WorklogItemModel>[];

  // Jelenleg megjelenítendő, szűrt bejegyzések.
  List<WorklogItemModel> _filteredLogs = <WorklogItemModel>[];

  final Set<String> _selectedProjectIds = <String>{};
  final Set<String> _selectedEmployeeIds = <String>{};
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  StreamSubscription<List<WorklogItemModel>>? _subscription;

  String? get teamId => _teamId;
  String? get error => _error;
  bool get isLoading => _isLoading;

  List<WorklogItemModel> get logs => _filteredLogs;

  /// Szűrt bejegyzések dátum szerint csoportosítva (nap szinten), legújabb először.
  List<MapEntry<DateTime, List<WorklogItemModel>>> get logsGroupedByDate {
    if (_filteredLogs.isEmpty) return [];
    final map = <DateTime, List<WorklogItemModel>>{};
    for (final log in _filteredLogs) {
      final day = DateTime(log.date.year, log.date.month, log.date.day);
      map.putIfAbsent(day, () => []).add(log);
    }
    final sortedDates = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return sortedDates.map((d) => MapEntry(d, map[d]!)).toList();
  }

  /// Dátum formázás a szekciófejlécekhez (pl. 2025.03.11.).
  String formatDate(DateTime date) => _formatDate(date);

  String formatDateForSectionHeader(DateTime date) =>
      _formatDateForSectionHeader(date);

  Set<String> get selectedProjectIds => _selectedProjectIds;
  Set<String> get selectedEmployeeIds => _selectedEmployeeIds;
  DateTime? get filterStartDate => _filterStartDate;
  DateTime? get filterEndDate => _filterEndDate;

  bool get hasActiveFilters =>
      _selectedProjectIds.isNotEmpty ||
      _selectedEmployeeIds.isNotEmpty ||
      _filterStartDate != null ||
      _filterEndDate != null;

  Future<void> _init() async {
    _setLoading(true);
    try {
      _teamId = await UserService.getTeamId();
      if (_teamId == null || _teamId!.isEmpty) {
        _error = 'Nem található teamId';
        _setLoading(false);
        return;
      }

      final workspaceRef = _workspaceProvider.workspaceRef;
      if (workspaceRef == null) {
        _error = 'Nem található workspace a jelenlegi csapathoz.';
        _setLoading(false);
        return;
      }

      _subscribeToWorklogs(workspaceRef, _teamId!);
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
    }
  }

  void showEditWorklogBottomSheet(BuildContext context, WorklogItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditWorklogBottomSheet(item: item),
    );
  }

  void _subscribeToWorklogs(
    DocumentReference<Map<String, dynamic>> workspaceRef,
    String teamId,
  ) {
    _subscription?.cancel();
    _subscription = _worklogService
        .getHydratedWorklogs(workspaceRef, teamId)
        .listen(
          (logs) {
            _allLogs = logs;
            _applyFilters();
            _setLoading(false);
          },
          onError: (Object e, StackTrace s) {
            _error = e.toString();
            _setLoading(false);
          },
        );
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // --- Szűrők publikus API-ja ---

  void setDateRange(DateTime? start, DateTime? end) {
    _filterStartDate = start;
    _filterEndDate = end;
    _applyFilters();
  }

  void setSelectedEmployeeIds(Set<String> ids) {
    _selectedEmployeeIds
      ..clear()
      ..addAll(ids);
    _applyFilters();
  }

  void setSelectedProjectIds(Set<String> ids) {
    _selectedProjectIds
      ..clear()
      ..addAll(ids);
    _applyFilters();
  }

  void clearFilters() {
    _filterStartDate = null;
    _filterEndDate = null;
    _selectedEmployeeIds.clear();
    _selectedProjectIds.clear();
    _applyFilters();
  }

  // --- Label segédfüggvények a UI-hoz ---

  String get dateFilterLabel {
    if (_filterStartDate == null && _filterEndDate == null) {
      return 'Dátumtartomány';
    }
    if (_filterStartDate != null && _filterEndDate != null) {
      return '${_formatDate(_filterStartDate!)} – ${_formatDate(_filterEndDate!)}';
    }
    if (_filterStartDate != null) {
      return 'From ${_formatDate(_filterStartDate!)}';
    }
    return 'Until ${_formatDate(_filterEndDate!)}';
  }

  String get colleagueFilterLabel {
    if (_selectedEmployeeIds.isEmpty) return 'Kollégák';
    return 'Kollégák (${_selectedEmployeeIds.length})';
  }

  String get projectFilterLabel {
    if (_selectedProjectIds.isEmpty) return 'Projektek';
    return 'Projektek (${_selectedProjectIds.length})';
  }

  // --- Belső szűrési logika ---

  void _applyFilters() {
    var result = _allLogs;
    result = _filterByDateRange(result);
    result = _filterByColleaguesAndProjects(result);
    _filteredLogs = result;
    notifyListeners();
  }

  List<WorklogItemModel> _filterByColleaguesAndProjects(
    List<WorklogItemModel> items,
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

  List<WorklogItemModel> _filterByDateRange(List<WorklogItemModel> items) {
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

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}.';
  }

  String _formatDateForSectionHeader(DateTime date) {
    // Use DateTime weekday (1=Monday,...,7=Sunday, ISO 8601)
    const weekdays = [
      'Hétfő',
      'Kedd',
      'Szerda',
      'Csütörtök',
      'Péntek',
      'Szombat',
      'Vasárnap',
    ];
    final dayName = weekdays[date.weekday - 1];
    const monthNames = [
      'január',
      'február',
      'március',
      'április',
      'május',
      'június',
      'július',
      'augusztus',
      'szeptember',
      'október',
      'november',
      'december',
    ];
    final monthName = monthNames[date.month - 1];
    return '${date.year}. $monthName ${date.day}. - $dayName';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
