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

  const double minChildSize = 0.25;
  const double maxChildSize = 0.95;

  return showModalBottomSheet<void>(
    showDragHandle: true,
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final initialSize = heightFraction.clamp(minChildSize, maxChildSize);

      return StatefulBuilder(
        builder: (context, setModalState) {
          final selectionUnchanged =
              selectedEmployeeIds.length == initialSelection.length &&
              selectedEmployeeIds.every((id) => initialSelection.contains(id));
          final showKeszButton = !selectionUnchanged;

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: initialSize,
            minChildSize: minChildSize,
            maxChildSize: maxChildSize,
            builder: (context, scrollController) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          sliver: SliverToBoxAdapter(
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        if (availableEmployees.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: showKeszButton ? 88 : 24,
                              ),
                              child: Center(child: Text(emptyMessage)),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              showKeszButton ? 88 : 24,
                            ),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 0.75,
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final employee = availableEmployees[index];
                                final employeeId = employee['id'] as String;
                                final employeeName =
                                    (employee['name'] as String? ?? 'Névtelen')
                                        .trim();
                                final firstLetter =
                                    employeeName.isNotEmpty
                                        ? employeeName[0].toUpperCase()
                                        : '?';
                                final isSelected = selectedEmployeeIds.contains(
                                  employeeId,
                                );

                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      if (isSelected) {
                                        selectedEmployeeIds.remove(employeeId);
                                      } else {
                                        selectedEmployeeIds.add(employeeId);
                                      }
                                      onSelectionChanged(
                                        Set<String>.from(selectedEmployeeIds),
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
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.onPrimary,
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
                              }, childCount: availableEmployees.length),
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
              );
            },
          );
        },
      );
    },
  );
}
