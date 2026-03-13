import 'package:flutter/foundation.dart';
import 'package:okoskert_internal/data/services/users_services.dart';

/// ViewModel az órabér módosító bottom sheethez.
///
/// Feladata:
/// - órabér mentés a backendre
/// - mentés állapot (isSaving) kezelése
class SalaryEditViewModel extends ChangeNotifier {
  SalaryEditViewModel({
    required this.userId,
    required this.initialSalary,
    required this.name,
    required this.email,
  });

  final String userId;
  final int initialSalary;
  final String name;
  final String email;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _error;
  String? get error => _error;

  /// Órabér mentése. Sikeres mentés után nincs kivétel; hiba esetén kivételt dob.
  Future<void> saveSalary(int salary) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await UsersServices.updateUserSalary(userId: userId, salary: salary);
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
