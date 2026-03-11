import 'package:cloud_firestore/cloud_firestore.dart';

/// Egységes megoldás a felhasználó/dolgozó ID alapján történő név lekérdezésére.
/// A `users` gyűjteményből olvas; a eredményeket memóriában cache-eli.
class EmployeeNameService {
  static final Map<String, String> _cache = {};

  /// Egy felhasználó megjelenített neve ID alapján.
  /// A users dokumentumból a `name`, ha nincs akkor `email`, egyébként "Ismeretlen".
  static Future<String> getEmployeeName(String userId) async {
    if (userId.isEmpty) return 'Ismeretlen';
    if (_cache.containsKey(userId)) return _cache[userId]!;

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
      if (!doc.exists || doc.data() == null) {
        _cache[userId] = userId;
        return userId;
      }
      final data = doc.data()!;
      final name = (data['name'] as String?)?.trim();
      final email = (data['email'] as String?)?.trim();
      final display =
          name?.isNotEmpty == true
              ? name!
              : (email?.isNotEmpty == true ? email! : 'Ismeretlen');
      _cache[userId] = display;
      return display;
    } catch (_) {
      _cache[userId] = userId;
      return userId;
    }
  }

  /// Több felhasználó neve egy hívással (cache-eléssel).
  /// Visszaadja az id -> megjelenített név mapot.
  static Future<Map<String, String>> getEmployeeNames(
    List<String> userIds,
  ) async {
    final uniqueIds = userIds.where((id) => id.isNotEmpty).toSet().toList();
    if (uniqueIds.isEmpty) return {};

    final result = <String, String>{};
    final missing = <String>[];
    for (final id in uniqueIds) {
      if (_cache.containsKey(id)) {
        result[id] = _cache[id]!;
      } else {
        missing.add(id);
      }
    }
    if (missing.isEmpty) return result;

    for (final id in missing) {
      try {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(id).get();
        if (!doc.exists || doc.data() == null) {
          _cache[id] = id;
          result[id] = id;
        } else {
          final data = doc.data()!;
          final name = (data['name'] as String?)?.trim();
          final email = (data['email'] as String?)?.trim();
          final display =
              name?.isNotEmpty == true
                  ? name!
                  : (email?.isNotEmpty == true ? email! : 'Ismeretlen');
          _cache[id] = display;
          result[id] = display;
        }
      } catch (_) {
        _cache[id] = id;
        result[id] = id;
      }
    }
    return result;
  }

  /// Cache ürítése (pl. kijelentkezéskor).
  static void clearCache() {
    _cache.clear();
  }
}
