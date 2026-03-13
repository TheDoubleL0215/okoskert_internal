import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:okoskert_internal/features/admin/collegues_management/models/colleague_item.dart';
import 'package:okoskert_internal/features/admin/collegues_management/viewmodel/salary_edit_view_model.dart';

class ColleagueEditSalaryBottomSheet extends StatefulWidget {
  final ColleagueItem colleague;

  const ColleagueEditSalaryBottomSheet({required this.colleague});

  @override
  State<ColleagueEditSalaryBottomSheet> createState() =>
      _ColleagueEditSalaryBottomSheetState();
}

class _ColleagueEditSalaryBottomSheetState
    extends State<ColleagueEditSalaryBottomSheet> {
  final _salaryController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final SalaryEditViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _salaryController.text = widget.colleague.salary.toString();
    _viewModel = SalaryEditViewModel(
      userId: widget.colleague.id,
      initialSalary: widget.colleague.salary,
      name: widget.colleague.name,
      email: widget.colleague.email,
    );
    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() => setState(() {});

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _saveSalary() async {
    if (!_formKey.currentState!.validate()) return;

    final salary = int.parse(_salaryController.text.trim());

    try {
      await _viewModel.saveSalary(salary);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Fizetés sikeresen mentve')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mentési hiba: ${_viewModel.error}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Órabér módosítása',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Text(
                '${widget.colleague.name}\n(${widget.colleague.email})',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _salaryController,
                enabled: !_viewModel.isSaving,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Új órabér (Ft)',
                  hintText: 'Pl. 4500',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final input = (value ?? '').trim();
                  if (input.isEmpty) return 'Add meg a fizetést';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _viewModel.isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Mégse'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _viewModel.isSaving
                          ? null
                          : _saveSalary,
                      child: _viewModel.isSaving
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Mentés'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
