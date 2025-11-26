import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/project_data_collegues/ColleagueWorklogEntryEdit.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/project_data_collegues/ProjectAddDataCollegues.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/project_data_images/ProjectImages.dart';

class ProjectDataScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  const ProjectDataScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ProjectDataScreen> createState() => _ProjectDataScreenState();
}

class _ProjectDataScreenState extends State<ProjectDataScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ExpandableFabState> _fab = GlobalKey<ExpandableFabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.projectName,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Munkaórák'), Tab(text: 'Képek')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDataTab(),
          ProjectImagesScreen(projectId: widget.projectId),
        ],
      ),
    );
  }

  Widget _buildDataTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        label: Text(
          'Új munkaóra hozzáadása',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          _fab.currentState?.close();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ProjectAddDataCollegues(
                    projectId: widget.projectId,
                    projectName: widget.projectName,
                  ),
            ),
          );
        },
        icon: Icon(Icons.person_add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection('projects')
                .doc(widget.projectId)
                .collection('worklog')
                .orderBy('date', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Hiba történt a munkanapló betöltésekor: ${snapshot.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final worklogDocs = snapshot.data?.docs ?? [];

          if (worklogDocs.isEmpty) {
            return const Center(
              child: Text(
                'Még nincsenek munkanapló bejegyzések',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          // Csoportosítás dátum szerint
          final groupedByDate =
              <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

          for (final doc in worklogDocs) {
            final data = doc.data();
            final date = data['date'] as Timestamp?;
            if (date != null) {
              final dateKey = _getDateKey(date.toDate());
              groupedByDate.putIfAbsent(dateKey, () => []).add(doc);
            }
          }

          // Dátumok rendezése (legújabb elöl)
          final sortedDates =
              groupedByDate.keys.toList()..sort((a, b) => b.compareTo(a));

          // Flattened lista: fejlécek + bejegyzések
          final items = <_WorklogItem>[];
          for (final dateKey in sortedDates) {
            items.add(_WorklogItem.isHeader(dateKey));
            for (final doc in groupedByDate[dateKey]!) {
              items.add(_WorklogItem.isEntry(doc));
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              if (item.isHeader) {
                // Dátum fejléc
                final dateParts = item.dateKey!.split('-');
                final formattedDate =
                    '${dateParts[0]}. ${dateParts[1]}. ${dateParts[2]}.';
                return Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Text(
                    formattedDate,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                );
              } else {
                // Bejegyzés
                final doc = item.doc!;
                final data = doc.data();

                final employeeName =
                    data['employeeName'] as String? ?? 'Ismeretlen';
                final startTime = data['startTime'] as Timestamp?;
                final endTime = data['endTime'] as Timestamp?;
                final breakMinutes = data['breakMinutes'] as int? ?? 0;
                final date = data['date'] as Timestamp?;
                final description = data['description'] as String? ?? '';

                return Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(child: const Icon(Icons.person)),
                      title: Text(employeeName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (startTime != null && endTime != null)
                            Text(
                              'Időtartam: ${_formatTime(startTime.toDate())} - ${_formatTime(endTime.toDate())}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          if (breakMinutes > 0)
                            Text(
                              'Szünet: $breakMinutes perc',
                              style: const TextStyle(fontSize: 12),
                            ),
                          if (description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Row(
                                spacing: 4,
                                children: [
                                  Icon(Icons.sticky_note_2_outlined, size: 16),
                                  Text(
                                    description,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      onTap:
                          () => _showEditBottomSheet(
                            context,
                            doc,
                            startTime?.toDate(),
                            endTime?.toDate(),
                            breakMinutes,
                            date?.toDate(),
                            description,
                          ),
                    ),
                    const Divider(),
                  ],
                );
              }
            },
          );
        },
      ),
    );
  }

  String _getDateKey(DateTime date) {
    // YYYY-MM-DD formátum a csoportosításhoz
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showEditBottomSheet(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    DateTime? initialStartTime,
    DateTime? initialEndTime,
    int initialBreakMinutes,
    DateTime? initialDate,
    String? initialDescription,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => EditWorklogBottomSheet(
            doc: doc,
            projectId: widget.projectId,
            initialStartTime: initialStartTime,
            initialEndTime: initialEndTime,
            initialBreakMinutes: initialBreakMinutes,
            initialDate: initialDate,
            initialDescription: initialDescription,
          ),
    );
  }
}

// Helper class a ListView itemek reprezentálásához
class _WorklogItem {
  final bool isHeader;
  final String? dateKey;
  final QueryDocumentSnapshot<Map<String, dynamic>>? doc;

  _WorklogItem._({required this.isHeader, this.dateKey, this.doc});

  factory _WorklogItem.isHeader(String dateKey) {
    return _WorklogItem._(isHeader: true, dateKey: dateKey);
  }

  factory _WorklogItem.isEntry(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return _WorklogItem._(isHeader: false, doc: doc);
  }
}
