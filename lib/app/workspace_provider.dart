import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:okoskert_internal/data/services/workspace_service.dart';

/// Globálisan elérhető workspace referencia a bejelentkezett felhasználó munkatéréhez.
/// Bejelentkezéskor betöltjük, kijelentkezéskor töröljük.
class WorkspaceProvider extends ChangeNotifier {
  DocumentReference<Map<String, dynamic>>? _workspaceRef;
  bool _isLoading = false;
  String? _error;

  DocumentReference<Map<String, dynamic>>? get workspaceRef => _workspaceRef;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Betölti a jelenlegi csapat workspace referenciáját.
  Future<void> loadWorkspaceRef() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _workspaceRef =
          await WorkspaceService.getWorkspaceRefForCurrentTeam();
    } catch (e) {
      _error = e.toString();
      _workspaceRef = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Törli a workspace ref-et (pl. kijelentkezéskor).
  void clearWorkspaceRef() {
    _workspaceRef = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
