import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectService {
  /// Lekérdezi a projekt adatait a Firestore "projects" kollekcióból az ID alapján
  ///
  /// [projectId] - A projekt dokumentum ID-ja
  /// Visszatér a projekt adataival Map formátumban, vagy null-t, ha nem található
  static Future<Map<String, dynamic>?> getProjectById(String projectId) async {
    try {
      final docSnapshot =
          await FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .get();

      if (!docSnapshot.exists) {
        return null;
      }

      return {
        'id': docSnapshot.id,
        ...docSnapshot.data() as Map<String, dynamic>,
      };
    } catch (e) {
      rethrow;
    }
  }
}
