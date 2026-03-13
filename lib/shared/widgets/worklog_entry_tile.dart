import 'package:flutter/material.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/ProjectDataScreen.dart';
import 'package:okoskert_internal/features/worklog/models/worklog_item_model.dart';

/// Egy munkanapló bejegyzés megjelenítése (dolgozó név, időtartam, szünet, leírás).
/// Használható a projekt munkanapló és a globális munkanapló képernyőkön.
class WorklogEntryTile extends StatelessWidget {
  final WorklogItemModel item;
  final VoidCallback? onTap;

  const WorklogEntryTile({super.key, required this.item, this.onTap});

  static String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.employeeName ?? 'Ismeretlen felhasználó',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.projectName != null && item.projectName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Flexible(
                          child: ActionChip(
                            avatar: const Icon(Icons.tag, size: 18),
                            label: Text(
                              item.projectName!,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            onPressed:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => ProjectDataScreen(
                                          projectId: item.projectId!,
                                          projectName: item.projectName!,
                                        ),
                                  ),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Chip(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                side: BorderSide.none,
                label: Text(
                  '${_formatTime(item.startTime)} - ${_formatTime(item.endTime)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              if (item.breakMinutes > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Szünet: ${item.breakMinutes} perc',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
