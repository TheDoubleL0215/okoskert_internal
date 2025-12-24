import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';

class EmployeeService {
  /// Lekérdezi az összes dolgozót a Firestore "users" kollekcióból,
  /// ahol a felhasználó teamId-je megegyezik a SharedPreferences-ben tárolt teamId-vel
  ///
  /// Visszatér a dolgozók listájával Map formátumban
  static Future<List<Map<String, dynamic>>> getEmployees() async {
    try {
      final teamId = await UserService.getTeamId();

      if (teamId == null || teamId.isEmpty) {
        return [];
      }

      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('teamId', isEqualTo: teamId)
              .get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    } catch (e) {
      rethrow;
    }
  }
}
