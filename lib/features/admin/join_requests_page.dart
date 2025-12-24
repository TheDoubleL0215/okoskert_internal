import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';

class JoinRequestsPage extends StatelessWidget {
  const JoinRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Csatlakozási kérelmek')),
      body: FutureBuilder<String?>(
        future: UserService.getTeamId(),
        builder: (context, teamIdSnapshot) {
          if (teamIdSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final teamId = teamIdSnapshot.data;
          if (teamId == null) {
            return const Center(
              child: Text('Nem található munkatér azonosító'),
            );
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

                  if (joinRequests.isEmpty) {
                    return const Center(
                      child: Text('Nincsenek függőben lévő kérelmek'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: joinRequests.length,
                    itemBuilder: (context, index) {
                      final request = joinRequests[index];
                      final requestData = request.data();
                      final userId = requestData['userId'] as String?;
                      final name = requestData['name'] as String? ?? 'Névtelen';
                      final email = requestData['email'] as String? ?? '';

                      return _JoinRequestCard(
                        requestId: request.id,
                        userId: userId ?? '',
                        name: name,
                        email: email,
                        workspaceRef: workspaceDoc.reference,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _JoinRequestCard extends StatefulWidget {
  final String requestId;
  final String userId;
  final String name;
  final String email;
  final DocumentReference workspaceRef;

  const _JoinRequestCard({
    required this.requestId,
    required this.userId,
    required this.name,
    required this.email,
    required this.workspaceRef,
  });

  @override
  State<_JoinRequestCard> createState() => _JoinRequestCardState();
}

class _JoinRequestCardState extends State<_JoinRequestCard> {
  String? _selectedRole;
  bool _isProcessing = false;

  final Map<String, int> _roleMap = {
    'Admin': 1,
    'Építésvezető': 2,
    'Kertész': 3,
  };

  Future<void> _acceptRequest() async {
    if (_selectedRole == null || widget.userId.isEmpty) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Frissítjük a felhasználó role-ját
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'role': _roleMap[_selectedRole]});

      // Töröljük a joinRequest-et
      await widget.workspaceRef
          .collection('joinRequests')
          .doc(widget.requestId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.name} sikeresen hozzáadva ${_selectedRole} szerepkörrel',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hiba történt: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    widget.name.isNotEmpty ? widget.name[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.email,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Szerepkör',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items:
                  _roleMap.keys.map((String role) {
                    return DropdownMenuItem<String>(
                      value: role,
                      child: Text(role),
                    );
                  }).toList(),
              onChanged:
                  _isProcessing
                      ? null
                      : (String? newValue) {
                        setState(() {
                          _selectedRole = newValue;
                        });
                      },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    _isProcessing || _selectedRole == null
                        ? null
                        : _acceptRequest,
                child:
                    _isProcessing
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Elfogadás'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
