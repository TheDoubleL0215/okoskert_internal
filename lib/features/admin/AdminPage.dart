import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/features/admin/join_requests_page.dart';
import 'package:okoskert_internal/features/admin/work_types_page.dart';
import 'package:okoskert_internal/features/admin/colleagues_page.dart';
import 'package:okoskert_internal/features/admin/admin_menu_tile.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Nincs bejelentkezett felhasználó')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: Text('Felhasználó nem található'));
          }

          final userData = userSnapshot.data!.data();
          final teamId = userData?['teamId'];

          if (teamId == null || teamId == '') {
            return const Center(child: Text('Nincs munkatérhez rendelve'));
          }

          // Keresünk egy workspace-t a teamId alapján
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance
                    .collection('workspaces')
                    .where('teamId', isEqualTo: teamId)
                    .limit(1)
                    .snapshots(),
            builder: (context, workspaceSnapshot) {
              if (workspaceSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!workspaceSnapshot.hasData ||
                  workspaceSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Munkatér nem található'));
              }

              final workspaceDoc = workspaceSnapshot.data!.docs.first;

              // Lekérdezzük a joinRequests-et
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    workspaceDoc.reference
                        .collection('joinRequests')
                        .snapshots(),
                builder: (context, joinRequestsSnapshot) {
                  if (joinRequestsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final joinRequests = joinRequestsSnapshot.data?.docs ?? [];
                  final hasPendingRequests = joinRequests.isNotEmpty;

                  return ListView(
                    children: [
                      if (hasPendingRequests)
                        AdminMenuTile(
                          icon: Icons.person_add,
                          title: 'Csatlakozási kérelmek',
                          trailing: Badge(
                            label: Text('${joinRequests.length}'),
                            child: const Icon(Icons.chevron_right),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const JoinRequestsPage(),
                              ),
                            );
                          },
                        ),
                      AdminMenuTile(
                        icon: Icons.work,
                        title: 'Munkatípusok kezelése',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WorkTypesPage(),
                            ),
                          );
                        },
                      ),
                      AdminMenuTile(
                        icon: Icons.people,
                        title: 'Munkatársak',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ColleaguesPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          FirebaseAuth.instance.signOut();
        },
        icon: const Icon(Icons.logout),
        label: const Text('Kijelentkezés'),
      ),
    );
  }
}
