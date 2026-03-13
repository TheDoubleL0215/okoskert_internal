import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectService {
  /// Lekérdezi a csapat projekteit a Firestore "projects" kollekcióból teamId alapján.
  /// Visszatér a projektek listájával Map formátumban (id, projectName, ...).
  static Future<List<Map<String, dynamic>>> getProjectsByTeamId(
    String teamId,
  ) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('projects')
              .where('teamId', isEqualTo: teamId)
              .get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      rethrow;
    }
  }

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

  static Future<List<Map<String, dynamic>>> getProjectNames(
    List<String> projectIds,
  ) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('projects')
              .where(FieldPath.documentId, whereIn: projectIds)
              .get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      rethrow;
    }
  }
}
