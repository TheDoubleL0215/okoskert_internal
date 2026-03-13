import 'package:flutter/material.dart';
import 'package:okoskert_internal/features/admin/collegues_management/viewmodel/add_colleague_view_model.dart';

class AddColleagueScreen extends StatefulWidget {
  const AddColleagueScreen({super.key});

  @override
  State<AddColleagueScreen> createState() => _AddColleagueScreenState();
}

class _AddColleagueScreenState extends State<AddColleagueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  late final AddColleagueViewModel _viewModel;
  int _selectedRole = 1;

  @override
  void initState() {
    super.initState();
    _viewModel = AddColleagueViewModel();
    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() => setState(() {});

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await _viewModel.addColleague(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        role: _selectedRole,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Munkatárs hozzáadva')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hiba: ${_viewModel.error}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Új munkatárs hozzáadása')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              enabled: !_viewModel.isSaving,
              decoration: const InputDecoration(
                labelText: 'Név',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return 'Add meg a nevet';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              enabled: !_viewModel.isSaving,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Add meg az e-mailt';
                if (!s.contains('@') || !s.contains('.')) {
                  return 'Érvényes e-mail címet adj meg';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Szerepkör',
                border: OutlineInputBorder(),
              ),
              items: List.generate(
                AddColleagueViewModel.roleValues.length,
                (i) => DropdownMenuItem<int>(
                  value: AddColleagueViewModel.roleValues[i],
                  child: Text(AddColleagueViewModel.roleLabels[i]),
                ),
              ),
              onChanged: _viewModel.isSaving
                  ? null
                  : (v) => setState(() => _selectedRole = v ?? 1),
              validator: (v) => v == null ? 'Válaszd ki a szerepkört' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _viewModel.isSaving ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _viewModel.isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Munkatárs hozzáadása'),
            ),
          ],
        ),
      ),
    );
  }
}
