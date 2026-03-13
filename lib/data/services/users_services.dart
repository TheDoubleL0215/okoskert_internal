import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';

class UsersServices {
  static Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getUsers() async* {
    final teamId = await UserService.getTeamId();
    if (teamId == null || teamId.isEmpty) {
      yield [];
      return;
    }

    yield* FirebaseFirestore.instance
        .collection('users')
        .where('teamId', isEqualTo: teamId)
        .snapshots()
        .map((snapshot) => snapshot.docs.toList());
  }

  static Future<void> updateUserSalary({
    required String userId,
    required int salary,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'salary': salary,
    });
  }

  /// Új munkatárs hozzáadása csak a Firestore users gyűjteményhez (nincs Auth).
  /// A teamId a bejelentkezett felhasználó csapatából kerül.
  static Future<void> addUserToTeam({
    required String name,
    required String email,
    required int role,
  }) async {
    final teamId = await UserService.getTeamId();
    if (teamId == null || teamId.isEmpty) {
      throw Exception('Nincs csapat az aktuális felhasználóhoz.');
    }

    await FirebaseFirestore.instance.collection('users').add({
      'name': name.trim(),
      'email': email.trim(),
      'role': role,
      'teamId': teamId,
      'salary': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
