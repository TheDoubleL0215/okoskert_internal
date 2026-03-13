import 'package:flutter/material.dart';
import 'package:okoskert_internal/app/workspace_provider.dart';
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (viewModel.error != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  viewModel.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            // Dolgozó dropdown
            DropdownButtonFormField<String>(
              value: viewModel.selectedEmployeeId,
              decoration: const InputDecoration(
                labelText: 'Dolgozó',
                border: OutlineInputBorder(),
              ),
              items:
                  viewModel.employees.map<DropdownMenuItem<String>>((e) {
                    final id = e['id'] as String? ?? '';
                    final label = (e['name'] ?? e['email'] ?? id).toString();
                    return DropdownMenuItem(value: id, child: Text(label));
                  }).toList(),
              onChanged: (value) => viewModel.setSelectedEmployeeId(value),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Válassz dolgozót.';
                }
                return null;
              },
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
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: viewModel.date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) viewModel.setDate(picked);
              },
            ),
            const SizedBox(height: 20),
            // Kezdőidő
            ListTile(
              title: const Text('Kezdőidő'),
              subtitle: Text(
                CreateNewWorklogViewModel.formatTime(viewModel.startTime),
              ),
              trailing: const Icon(Icons.access_time),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(viewModel.startTime),
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
            const SizedBox(height: 12),
            // Végidő
            ListTile(
              title: const Text('Végidő'),
              subtitle: Text(
                CreateNewWorklogViewModel.formatTime(viewModel.endTime),
              ),
              trailing: const Icon(Icons.access_time),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(viewModel.endTime),
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
            const SizedBox(height: 20),
            // Leírás
            TextFormField(
              initialValue: viewModel.description,
              decoration: const InputDecoration(
                labelText: 'Leírás (opcionális)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
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
                                content: Text('Munkaóra sikeresen létrehozva.'),
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
    );
  }
}
