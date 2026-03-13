import 'package:flutter/foundation.dart';
import 'package:okoskert_internal/data/services/users_services.dart';

/// ViewModel az „Új munkatárs hozzáadása” képernyőhöz.
///
/// Feladata: új bejegyzés hozzáadása a Firestore users gyűjteményhez (teamId + role).
class AddColleagueViewModel extends ChangeNotifier {
  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _error;
  String? get error => _error;

  /// 1 = Admin, 2 = Építésvezető, 3 = Kertész
  static const List<int> roleValues = [1, 2, 3];
  static const List<String> roleLabels = ['Admin', 'Építésvezető', 'Kertész'];

  Future<void> addColleague({
    required String name,
    required String email,
    required int role,
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await UsersServices.addUserToTeam(
        name: name,
        email: email,
        role: role,
      );
      _isSaving = false;
      notifyListeners();
    } catch (e) {
      _isSaving = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
