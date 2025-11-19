import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProjectStatusChip extends StatefulWidget {
  final String projectId;
  final String currentStatus;
  final BuildContext context;
  const ProjectStatusChip({
    super.key,
    required this.context,
    required this.projectId,
    required this.currentStatus,
  });

  @override
  State<ProjectStatusChip> createState() => _ProjectStatusChipState();
}

enum ProjectStatus { ongoing, done, maintenance }

class _ProjectStatusChipState extends State<ProjectStatusChip> {
  String _getStatusLabel(String status) {
    switch (status) {
      case 'ongoing':
        return 'Folyamatban';
      case 'done':
        return 'Kész';
      case 'maintenance':
        return 'Karbantartás';
      default:
        return 'Folyamatban';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ongoing':
        return Colors.blue;
      case 'done':
        return Colors.green;
      case 'maintenance':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  void _showStatusBottomSheet(BuildContext context, String currentStatus) {
    ProjectStatus? _selectedStatus = ProjectStatus.values.firstWhere(
      (e) => e.name == widget.currentStatus,
    );

    showModalBottomSheet(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Állapot módosítása',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            style: IconButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close),
                          ),
                        ],
                      ),
                      RadioGroup<ProjectStatus>(
                        groupValue: _selectedStatus,
                        onChanged: (value) {
                          setModalState(() {
                            _selectedStatus = value;
                          });
                        },
                        child: Column(
                          children: const [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('Folyamatban'),
                              leading: Radio<ProjectStatus>(
                                value: ProjectStatus.ongoing,
                              ),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('Kész'),
                              leading: Radio<ProjectStatus>(
                                value: ProjectStatus.done,
                              ),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('Karbantartás'),
                              leading: Radio<ProjectStatus>(
                                value: ProjectStatus.maintenance,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            _showConfirmDialog(
                              context,
                              widget.currentStatus,
                              _selectedStatus?.name ?? '',
                            );
                          },
                          child: const Text('Módosítás'),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  void _showConfirmDialog(
    BuildContext context,
    String oldStatus,
    String newStatus,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Állapot módosítása'),
            content: Text(
              'Biztosan megváltoztatod a projekt állapotát?  "${_getStatusLabel(oldStatus)}" -> "${_getStatusLabel(newStatus)}"',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Mégse'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  _updateProjectStatus(newStatus);
                },
                child: const Text('Módosítás'),
              ),
            ],
          ),
    );
  }

  Future<void> _updateProjectStatus(String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({'projectStatus': newStatus});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Projekt állapota sikeresen frissítve: ${_getStatusLabel(newStatus)}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba történt a frissítéskor: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ActionChip(
            label: Text(_getStatusLabel(widget.currentStatus)),
            avatar: Icon(
              Icons.circle,
              size: 12,
              color: _getStatusColor(widget.currentStatus),
            ),
            onPressed: null,
            backgroundColor: _getStatusColor(
              widget.currentStatus,
            ).withValues(alpha: 0.1),
            side: BorderSide(color: _getStatusColor(widget.currentStatus)),
          );
        }

        if (snapshot.hasError) {
          return ActionChip(
            label: Text(_getStatusLabel(widget.currentStatus)),
            avatar: Icon(
              Icons.circle,
              size: 12,
              color: _getStatusColor(widget.currentStatus),
            ),
            onPressed:
                () => _showStatusBottomSheet(context, widget.currentStatus),
            backgroundColor: _getStatusColor(
              widget.currentStatus,
            ).withValues(alpha: 0.1),
            side: BorderSide(color: _getStatusColor(widget.currentStatus)),
          );
        }

        final projectData = snapshot.data?.data();
        final currentStatus =
            projectData?['projectStatus'] as String? ?? widget.currentStatus;

        return ActionChip(
          label: Text(_getStatusLabel(currentStatus)),
          avatar: Icon(
            Icons.circle,
            size: 12,
            color: _getStatusColor(currentStatus),
          ),
          onPressed: () => _showStatusBottomSheet(context, currentStatus),
          backgroundColor: _getStatusColor(
            currentStatus,
          ).withValues(alpha: 0.1),
          side: BorderSide(color: _getStatusColor(currentStatus)),
        );
      },
    );
  }
}
