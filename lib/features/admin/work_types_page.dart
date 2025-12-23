import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';

class WorkTypesPage extends StatefulWidget {
  const WorkTypesPage({super.key});

  @override
  State<WorkTypesPage> createState() => _WorkTypesPageState();
}

class _WorkTypesPageState extends State<WorkTypesPage> {
  final _newWorkTypeController = TextEditingController();
  String? _teamId;

  @override
  void initState() {
    super.initState();
    _loadTeamId();
  }

  Future<void> _loadTeamId() async {
    final teamId = await UserService.getTeamId();
    setState(() {
      _teamId = teamId;
    });
  }

  @override
  void dispose() {
    _newWorkTypeController.dispose();
    super.dispose();
  }

  Future<void> _addWorkType() async {
    if (_newWorkTypeController.text.trim().isEmpty || _teamId == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('workTypes').add({
        'name': _newWorkTypeController.text.trim(),
        'teamId': _teamId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _newWorkTypeController.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hiba történt: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_teamId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Munkatípusok kezelése')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Lekérdezzük a workTypes-et közvetlenül a root szintről, teamId alapján
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('workTypes')
              .where('teamId', isEqualTo: _teamId)
              .snapshots(),
      builder: (context, workTypesSnapshot) {
        return Scaffold(
          appBar: AppBar(title: const Text('Munkatípusok kezelése')),
          body: GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  ListTile(
                    title: TextField(
                      controller: _newWorkTypeController,
                      decoration: const InputDecoration(
                        labelText: 'Új munkatípus',
                      ),
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) => _addWorkType(),
                    ),
                    trailing: IconButton(
                      onPressed: _addWorkType,
                      icon: const CircleAvatar(child: Icon(Icons.add)),
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child:
                        workTypesSnapshot.connectionState ==
                                ConnectionState.waiting
                            ? const Center(child: CircularProgressIndicator())
                            : workTypesSnapshot.hasError
                            ? Center(
                              child: GestureDetector(
                                onTap: () {
                                  print(
                                    'Hiba történt: ${workTypesSnapshot.error}',
                                  );
                                },
                                child: Text(
                                  'Hiba történt: ${workTypesSnapshot.error}',
                                ),
                              ),
                            )
                            : workTypesSnapshot.data?.docs.isEmpty ?? true
                            ? const Center(
                              child: Text('Nincsenek munkatípusok'),
                            )
                            : ListView.builder(
                              itemCount:
                                  workTypesSnapshot.data?.docs.length ?? 0,
                              itemBuilder: (context, index) {
                                final workType =
                                    workTypesSnapshot.data!.docs[index];
                                final workTypeData = workType.data();
                                final name =
                                    workTypeData['name'] as String? ?? '';

                                return ListTile(
                                  title: Text(name),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () async {
                                      try {
                                        await workType.reference.delete();
                                      } catch (error) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Hiba történt: $error',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
