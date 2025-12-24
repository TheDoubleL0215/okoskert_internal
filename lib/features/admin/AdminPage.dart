import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      appBar: AppBar(
        title: const Text(
          'Admin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
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
              final workspaceData = workspaceDoc.data();
              final workspaceName =
                  workspaceData['name'] as String? ?? 'Névtelen munkatér';
              final workspaceTeamId =
                  workspaceData['teamId'] as String? ?? teamId;

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
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.business,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Munkatér információ',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _InfoRow(
                                label: 'Név',
                                value: workspaceName,
                                icon: Icons.badge,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _InfoRow(
                                      label: 'Csapat azonosító',
                                      value: workspaceTeamId,
                                      icon: Icons.vpn_key,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: workspaceTeamId),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Csapat azonosító másolva',
                                          ),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.copy),
                                    tooltip: 'Másolás',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
