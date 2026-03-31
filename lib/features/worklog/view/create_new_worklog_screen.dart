import 'package:flutter/material.dart';
import 'package:okoskert_internal/app/workspace_provider.dart';
import 'package:okoskert_internal/features/calendar/ui/employee_selection_bottom_sheet.dart';
import 'package:okoskert_internal/features/calendar/ui/selected_employees_section.dart';
import 'package:okoskert_internal/features/worklog/viewmodel/create_new_wroklog_viewmodal.dart';
import 'package:provider/provider.dart';

class CreateNewWorklogScreen extends StatelessWidget {
  const CreateNewWorklogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workspaceProvider = context.watch<WorkspaceProvider>();
    final workspaceRef = workspaceProvider.workspaceRef;

    if (workspaceRef == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Új munkaóra bejegyzés')),
        body: const Center(child: Text('Nem található workspace.')),
      );
    }

    return ChangeNotifierProvider<CreateNewWorklogViewModel>(
      create:
          (_) =>
              CreateNewWorklogViewModel(workspaceProvider: workspaceProvider),
      child: const _CreateNewWorklogForm(),
    );
  }
}

class _CreateNewWorklogForm extends StatefulWidget {
  const _CreateNewWorklogForm();

  @override
  State<_CreateNewWorklogForm> createState() => _CreateNewWorklogFormState();
}

class _CreateNewWorklogFormState extends State<_CreateNewWorklogForm> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CreateNewWorklogViewModel>();

    if (viewModel.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Új munkaóra bejegyzés')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Új munkaóra bejegyzés')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (viewModel.error != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    viewModel.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              FormField<void>(
                validator: (_) {
                  if (viewModel.selectedEmployeeIds.isEmpty) {
                    return 'Válassz legalább egy dolgozót.';
                  }
                  return null;
                },
                builder:
                    (fieldState) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectedEmployeesSection(
                          availableEmployees: viewModel.employees,
                          assignedEmployeeIds:
                              viewModel.selectedEmployeeIds.toList(),
                          onEditPressed: () {
                            showEmployeeSelectionBottomSheet(
                              context: context,
                              availableEmployees: viewModel.employees,
                              initialSelectedIds: Set<String>.from(
                                viewModel.selectedEmployeeIds,
                              ),
                              onSelectionChanged: (ids) {
                                viewModel.setSelectedEmployeeIds(ids);
                                fieldState.didChange(null);
                                fieldState.validate();
                              },
                            );
                          },
                        ),
                        if (fieldState.hasError) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              fieldState.errorText!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
              ),
              const SizedBox(height: 20),
              // Dátum
              ListTile(
                title: const Text('Dátum'),
                subtitle: Text(
                  CreateNewWorklogViewModel.formatDate(viewModel.date),
                ),
                trailing: const Icon(Icons.calendar_today),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                onTap: () async {
                  final today = DateTime.now();
                  final lastSelectable = DateTime(
                    today.year,
                    today.month,
                    today.day,
                  );
                  var initial = DateTime(
                    viewModel.date.year,
                    viewModel.date.month,
                    viewModel.date.day,
                  );
                  if (initial.isAfter(lastSelectable)) {
                    initial = lastSelectable;
                  }
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(2000),
                    lastDate: lastSelectable,
                  );
                  if (picked != null) viewModel.setDate(picked);
                },
              ),
              const SizedBox(height: 20),
              // Kezdőidő
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Kezdőidő'),
                      subtitle: Text(
                        CreateNewWorklogViewModel.formatTime(
                          viewModel.startTime,
                        ),
                      ),
                      trailing: const Icon(Icons.access_time),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            viewModel.startTime,
                          ),
                        );
                        if (picked != null) {
                          viewModel.setStartTime(
                            DateTime(
                              viewModel.date.year,
                              viewModel.date.month,
                              viewModel.date.day,
                              picked.hour,
                              picked.minute,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Végidő
                  Expanded(
                    child: ListTile(
                      title: const Text('Végidő'),
                      subtitle: Text(
                        CreateNewWorklogViewModel.formatTime(viewModel.endTime),
                      ),
                      trailing: const Icon(Icons.access_time),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            viewModel.endTime,
                          ),
                        );
                        if (picked != null) {
                          viewModel.setEndTime(
                            DateTime(
                              viewModel.date.year,
                              viewModel.date.month,
                              viewModel.date.day,
                              picked.hour,
                              picked.minute,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              // Leírás
              TextFormField(
                initialValue: viewModel.description,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Leírás (opcionális)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 2,
                onChanged: viewModel.setDescription,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed:
                    viewModel.isSaving
                        ? null
                        : () async {
                          if (_formKey.currentState?.validate() ?? false) {
                            final ok = await viewModel.save(context);
                            if (ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Munkaóra sikeresen létrehozva.',
                                  ),
                                ),
                              );
                              Navigator.pop(context);
                            }
                          }
                        },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child:
                    viewModel.isSaving
                        ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Mentés'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
