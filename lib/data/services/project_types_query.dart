import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';

class ProjectTypeService {
  static Future<List<Map<String, dynamic>>> getWorkTypesOnce() async {
    final teamId = await UserService.getTeamId();
    
    if (teamId == null || teamId.isEmpty) {
      return [];
    }

    // First, find the workspace by teamId
    final workspaceQuery = await FirebaseFirestore.instance
        .collection('workspaces')
        .where('teamId', isEqualTo: teamId)
        .limit(1)
        .get();

    if (workspaceQuery.docs.isEmpty) {
      return [];
    }

    final workspaceDoc = workspaceQuery.docs.first;

    // Then, get workTypes from the workspace subcollection
    final snapshot =
        await workspaceDoc.reference.collection('workTypes').get();

    return snapshot.docs.map((doc) {
      return {'id': doc.id, ...doc.data()};
    }).toList();
  }
}
