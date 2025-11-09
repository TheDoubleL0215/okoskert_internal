import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okoskert_internal/features/machine_hours/AddWorkingHoursBottomSheet.dart';

class MachineDetailsScreen extends StatefulWidget {
  final String machineName;
  final String machineId;
  final String machineValue;
  const MachineDetailsScreen({
    super.key,
    required this.machineName,
    required this.machineId,
    required this.machineValue,
  });

  @override
  State<MachineDetailsScreen> createState() => _MachineDetailsScreenState();
}

class _MachineDetailsScreenState extends State<MachineDetailsScreen> {
  void _showAddWorkHoursModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => AddWorkHoursBottomSheet(machineId: widget.machineId),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}. ${date.month.toString().padLeft(2, '0')}. ${date.day.toString().padLeft(2, '0')}.';
  }

  // Cache to store already fetched projects
  final Map<String, String> _projectNameCache = {};

  Future<void> _loadProjectNames(List<String> projectIds) async {
    // Filter out already cached ones
    final missingIds =
        projectIds.where((id) => !_projectNameCache.containsKey(id)).toList();
    if (missingIds.isEmpty) return;

    // Firestore whereIn only supports up to 10 items per query
    for (var i = 0; i < missingIds.length; i += 10) {
      final batch = missingIds.skip(i).take(10).toList();
      final snapshot =
          await FirebaseFirestore.instance
              .collection('projects')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

      for (final doc in snapshot.docs) {
        _projectNameCache[doc.id] =
            doc.data()['projectName'] as String? ?? 'Névtelen projekt';
      }

      // Fill missing ones (in case some projectIds don’t exist)
      for (final id in batch) {
        _projectNameCache.putIfAbsent(id, () => 'Ismeretlen projekt');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gép részletei")),
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              spacing: 16,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Hero(
                  tag: widget.machineId,
                  child: const CircleAvatar(
                    radius: 32,
                    child: Icon(Icons.agriculture, size: 32),
                  ),
                ),
                Text(widget.machineName, style: const TextStyle(fontSize: 24)),
                const Spacer(),
                Text(widget.machineValue, style: const TextStyle(fontSize: 24)),
              ],
            ),
          ),
          const Divider(),
          // Work hours log
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance
                      .collection('machines')
                      .doc(widget.machineId)
                      .collection('workHoursLog')
                      .orderBy('date', descending: true)
                      .snapshots(),
              builder: (context, logSnapshot) {
                if (logSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (logSnapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Hiba történt az adatok betöltésekor: ${logSnapshot.error}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final logDocs = logSnapshot.data?.docs ?? [];
                if (logDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Még nincsenek óraállás bejegyzések',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                // Collect all unique project IDs from logs
                final projectIds =
                    logDocs
                        .map((d) => d.data()['assignedProjectId'])
                        .whereType<String>()
                        .toSet()
                        .toList();

                return FutureBuilder<void>(
                  future: _loadProjectNames(projectIds),
                  builder: (context, projectFuture) {
                    if (projectFuture.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: logDocs.length,
                      itemBuilder: (context, index) {
                        final data = logDocs[index].data();
                        final date = data['date'] as Timestamp?;
                        final previousHours =
                            data['previousHours'] as num? ?? 0;
                        final newHours = data['newHours'] as num? ?? 0;
                        final assignedProjectId =
                            data['assignedProjectId'] as String?;
                        final projectName =
                            assignedProjectId != null
                                ? _projectNameCache[assignedProjectId] ??
                                    'Ismeretlen projekt'
                                : null;

                        final dateText =
                            date != null
                                ? _formatDate(date.toDate())
                                : 'Ismeretlen dátum';
                        final subtitle =
                            projectName != null
                                ? '$projectName - $previousHours → $newHours'
                                : '$previousHours → $newHours';

                        return ListTile(
                          title: Text(dateText),
                          subtitle: Text(subtitle),
                        );
                      },
                      separatorBuilder: (context, index) => const Divider(),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWorkHoursModal,
        child: const Icon(Icons.add),
      ),
    );
  }
}
