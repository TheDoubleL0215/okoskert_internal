import 'package:flutter/material.dart';

/// Egy munkanapló bejegyzés megjelenítése (dolgozó név, időtartam, szünet, leírás).
/// Használható a projekt munkanapló és a globális munkanapló képernyőkön.
class WorklogEntryTile extends StatelessWidget {
  final String employeeName;
  final DateTime? startTime;
  final DateTime? endTime;
  final int breakMinutes;
  final String description;
  final String? projectName;
  final VoidCallback? onTap;
  final bool showDivider;

  const WorklogEntryTile({
    super.key,
    required this.employeeName,
    this.startTime,
    this.endTime,
    this.breakMinutes = 0,
    this.description = '',
    this.projectName,
    this.onTap,
    this.showDivider = false,
  });

  static String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(employeeName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (startTime != null && endTime != null)
                Text(
                  'Időtartam: ${_formatTime(startTime!)} - ${_formatTime(endTime!)}',
                  style: const TextStyle(fontSize: 12),
                ),
              if (breakMinutes > 0)
                Text(
                  'Szünet: $breakMinutes perc',
                  style: const TextStyle(fontSize: 12),
                ),
              if (projectName != null && projectName!.isNotEmpty)
                Text(
                  'Projekt: $projectName',
                  style: const TextStyle(fontSize: 12),
                ),
              if (description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    spacing: 4,
                    children: [
                      const Icon(Icons.sticky_note_2_outlined, size: 16),
                      Expanded(
                        child: Text(
                          description,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          onTap: onTap,
        ),
        if (showDivider) const Divider(),
      ],
    );
  }
}
