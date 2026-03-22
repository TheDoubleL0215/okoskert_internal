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
        if (selectedEmployees.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    selectedEmployees.map((employee) {
                      final employeeName =
                          (employee['name'] as String? ?? 'Névtelen').trim();
                      final firstLetter =
                          employeeName.isNotEmpty
                              ? employeeName[0].toUpperCase()
                              : '?';
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
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
                            ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
