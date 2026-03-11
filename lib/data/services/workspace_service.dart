import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';

class WorkspaceService {
  static Future<DocumentReference<Map<String, dynamic>>?>
  getWorkspaceRefForCurrentTeam() async {
    final teamId = await UserService.getTeamId();
    if (teamId == null || teamId.isEmpty) {
      return null;
    }

    final workspaceQuery =
        await FirebaseFirestore.instance
            .collection('workspaces')
            .where('teamId', isEqualTo: teamId)
            .limit(1)
            .get();

    if (workspaceQuery.docs.isEmpty) {
      return null;
    }

    return workspaceQuery.docs.first.reference;
  }
}
