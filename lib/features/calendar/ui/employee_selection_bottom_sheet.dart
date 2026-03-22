import 'package:flutter/material.dart';

Future<void> showEmployeeSelectionBottomSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> availableEmployees,
  required Set<String> initialSelectedIds,
  required void Function(Set<String> selectedIds) onSelectionChanged,
  String title = 'Munkatársak kiválasztása',
  String emptyMessage = 'Nincs elérhető munkatárs.',
  double heightFraction = 0.5,
}) {
  final availableIdSet =
      availableEmployees.map((e) => e['id'] as String).toSet();
  final Set<String> selectedEmployeeIds = Set<String>.from(
    initialSelectedIds.where(availableIdSet.contains),
  );
  final Set<String> initialSelection = Set<String>.from(selectedEmployeeIds);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final sheetHeight =
          MediaQuery.of(sheetContext).size.height * heightFraction;
      return StatefulBuilder(
        builder: (context, setModalState) {
          final selectionUnchanged =
              selectedEmployeeIds.length == initialSelection.length &&
              selectedEmployeeIds.every((id) => initialSelection.contains(id));
          final showKeszButton = !selectionUnchanged;

          return SizedBox(
            height: sheetHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    showKeszButton ? 88 : 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child:
                            availableEmployees.isEmpty
                                ? Center(child: Text(emptyMessage))
                                : GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio: 0.75,
                                      ),
                                  itemCount: availableEmployees.length,
                                  itemBuilder: (context, index) {
                                    final employee = availableEmployees[index];
                                    final employeeId = employee['id'] as String;
                                    final employeeName =
                                        (employee['name'] as String? ??
                                                'Névtelen')
                                            .trim();
                                    final firstLetter =
                                        employeeName.isNotEmpty
                                            ? employeeName[0].toUpperCase()
                                            : '?';
                                    final isSelected = selectedEmployeeIds
                                        .contains(employeeId);

                                    return GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          if (isSelected) {
                                            selectedEmployeeIds.remove(
                                              employeeId,
                                            );
                                          } else {
                                            selectedEmployeeIds.add(employeeId);
                                          }
                                          onSelectionChanged(
                                            Set<String>.from(
                                              selectedEmployeeIds,
                                            ),
                                          );
                                        });
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              CircleAvatar(
                                                radius: 40,
                                                backgroundColor:
                                                    isSelected
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .primaryContainer
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                child: Text(
                                                  firstLetter,
                                                  style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        isSelected
                                                            ? Theme.of(context)
                                                                .colorScheme
                                                                .onPrimaryContainer
                                                            : Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                              if (isSelected)
                                                Positioned(
                                                  right: -2,
                                                  bottom: -2,
                                                  child: CircleAvatar(
                                                    backgroundColor:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                    radius: 10,
                                                    child: Icon(
                                                      Icons.check,
                                                      size: 16,
                                                      color:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .onPrimary,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Flexible(
                                            child: Text(
                                              employeeName,
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
                if (showKeszButton)
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          elevation: 8,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(28),
                          clipBehavior: Clip.antiAlias,
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('Kész'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}
