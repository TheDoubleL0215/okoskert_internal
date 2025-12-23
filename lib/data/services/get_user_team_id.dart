import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  /// Lekérdezi a bejelentkezett felhasználó teamId-jét
  /// Először a SharedPreferences-ből próbálja, majd ha nincs, a Firestore-ból
  static Future<String?> getTeamId() async {
    try {
      // Először próbáljuk a SharedPreferences-ből (gyorsabb)
      final prefs = await SharedPreferences.getInstance();
      final cachedTeamId = prefs.getString('teamId');
      if (cachedTeamId != null && cachedTeamId.isNotEmpty) {
        return cachedTeamId;
      }

      // Ha nincs cache-ben, lekérdezzük a Firestore-ból
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return null;
      }

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!userDoc.exists) {
        return null;
      }

      final userData = userDoc.data();
      final teamId = userData?['teamId'] as String?;

      // Cache-eljük a SharedPreferences-be
      if (teamId != null && teamId.isNotEmpty) {
        await prefs.setString('teamId', teamId);
      }

      return teamId;
    } catch (e) {
      debugPrint('Hiba a teamId lekérdezésekor: $e');
      return null;
    }
  }

  /// Lekérdezi a bejelentkezett felhasználó role-ját
  static Future<int?> getRole() async {
    try {
      // Először próbáljuk a SharedPreferences-ből
      final prefs = await SharedPreferences.getInstance();
      final cachedRole = prefs.getInt('role');
      if (cachedRole != null) {
        return cachedRole;
      }

      // Ha nincs cache-ben, lekérdezzük a Firestore-ból
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return null;
      }

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!userDoc.exists) {
        return null;
      }

      final userData = userDoc.data();
      final role = userData?['role'];

      // Cache-eljük a SharedPreferences-be
      if (role != null) {
        final roleInt = role is int ? role : int.tryParse(role.toString());
        if (roleInt != null) {
          await prefs.setInt('role', roleInt);
          return roleInt;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Hiba a role lekérdezésekor: $e');
      return null;
    }
  }

  /// Frissíti a cache-t a Firestore-ból
  static Future<void> refreshCache() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!userDoc.exists) {
        return;
      }

      final userData = userDoc.data();
      final prefs = await SharedPreferences.getInstance();

      final teamId = userData?['teamId'] as String?;
      if (teamId != null && teamId.isNotEmpty) {
        await prefs.setString('teamId', teamId);
      }

      final role = userData?['role'];
      if (role != null) {
        final roleInt = role is int ? role : int.tryParse(role.toString());
        if (roleInt != null) {
          await prefs.setInt('role', roleInt);
        }
      }
    } catch (e) {
      debugPrint('Hiba a cache frissítésekor: $e');
    }
  }
}
