import 'package:flutter/material.dart';
import 'package:okoskert_internal/features/worklog/models/wage_type_option.dart';

Future<WageTypeOption?> showWageTypeSelectionBottomSheet({
  required BuildContext context,
  required List<WageTypeOption> wageTypes,
  WageTypeOption? initialSelection,
}) {
  return showModalBottomSheet<WageTypeOption>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      if (wageTypes.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Nincs elérhető bértípus.')),
        );
      }

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.45,
        minChildSize: 0.25,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Bértípus kiválasztása',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: wageTypes.length,
                  itemBuilder: (context, index) {
                    final wt = wageTypes[index];
                    final selected = initialSelection?.id == wt.id;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: selected ? 2 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color:
                              selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        title: Text(wt.name),
                        subtitle: Text(
                          'Alapértelmezett: ${wt.defaultValue} Ft',
                        ),
                        trailing:
                            selected
                                ? Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                                : null,
                        onTap: () => Navigator.of(sheetContext).pop(wt),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
