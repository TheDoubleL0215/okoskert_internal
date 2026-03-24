import 'package:flutter/material.dart';

class SelectedEmployeesSection extends StatelessWidget {
  final List<Map<String, dynamic>> availableEmployees;
  final List<String> assignedEmployeeIds;
  final VoidCallback onEditPressed;

  const SelectedEmployeesSection({
    super.key,
    required this.availableEmployees,
    required this.assignedEmployeeIds,
    required this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    final selectedEmployees =
        availableEmployees.where((emp) {
          return assignedEmployeeIds.contains(emp['id']);
        }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Munkatársak', style: Theme.of(context).textTheme.titleMedium),
            FilledButton.tonalIcon(
              onPressed: onEditPressed,
              icon:
                  assignedEmployeeIds.isEmpty
                      ? const Icon(Icons.add, size: 20)
                      : null,
              label: Text(
                assignedEmployeeIds.isEmpty ? 'Hozzárendelés' : 'Szerkesztés',
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child:
              selectedEmployees.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: selectedEmployees.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final employee = selectedEmployees[index];
                          final employeeName =
                              (employee['name'] as String? ?? 'Névtelen')
                                  .trim();
                          final firstLetter =
                              employeeName.isNotEmpty
                                  ? employeeName[0].toUpperCase()
                                  : '?';
                          return CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            child: Text(
                              firstLetter,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
        ),
      ],
    );
  }
}
