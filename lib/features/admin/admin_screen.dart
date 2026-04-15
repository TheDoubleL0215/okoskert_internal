import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:okoskert_internal/app/session_provider.dart';
import 'package:okoskert_internal/features/admin/workspace_settings/workspace_settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:okoskert_internal/app/settings_screen.dart';
import 'package:okoskert_internal/app/workspace_provider.dart';
import 'package:okoskert_internal/features/admin/collegues_management/view/colleagues_screen.dart';
import 'package:okoskert_internal/features/admin/join_request/join_requests_page.dart';
import 'package:okoskert_internal/features/admin/work_types_page.dart';
import 'package:okoskert_internal/features/admin/admin_menu_tile.dart';
import 'package:okoskert_internal/features/warehouse/warehouse_screen.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final user = session.user;
    final role = session.role;
    final wp = context.watch<WorkspaceProvider>();
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Nincs bejelentkezett felhasználó')),
      );
    }

    if (wp.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final workspaceRef = wp.workspaceRef;
    if (workspaceRef == null) {
      return const Center(child: Text('Nincs munkatérhez rendelve'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: workspaceRef.get(),
        builder: (context, workspaceSnapshot) {
          if (workspaceSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!workspaceSnapshot.hasData || !workspaceSnapshot.data!.exists) {
            return const Center(child: Text('Munkatér nem található'));
          }
          final workspaceData = workspaceSnapshot.data!.data();
          final workspaceName =
              workspaceData?['name'] as String? ?? 'Névtelen munkatér';
          final workspaceTeamId = workspaceData?['teamId'] as String? ?? '';

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: workspaceRef.collection('joinRequests').snapshots(),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.business,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Munkatér információ',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) =>
                                              const WorkspaceSettingsScreen(),
                                    ),
                                  );
                                },
                                child: const Text('Kezelés'),
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
                                  value: session.teamId ?? '',
                                  icon: Icons.vpn_key,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: workspaceTeamId),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Csapat azonosító másolva'),
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
                    icon: Icons.inventory_2,
                    title: 'Alapanyagok kezelése',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WarehouseScreen(),
                        ),
                      );
                    },
                  ),
                  if (role == 1)
                    AdminMenuTile(
                      icon: Icons.people,
                      title: 'Munkatársak kezelése',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ColleaguesManagementPage(),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Kijelentkezés'),
                  content: const Text('Biztosan ki szeretnél jelentkezni?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Mégse'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Kijelentkezés'),
                    ),
                  ],
                ),
          );

          if (confirmed == true) {
            await FirebaseAuth.instance.signOut();
          }
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
