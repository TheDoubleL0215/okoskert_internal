import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:okoskert_internal/app/workspace_provider.dart';
import 'package:okoskert_internal/features/admin/collegues_management/models/colleague_item.dart';
import 'package:provider/provider.dart';

class ColleagueEditSalaryBottomSheet extends StatefulWidget {
  final ColleagueItem colleague;

  const ColleagueEditSalaryBottomSheet({required this.colleague});

  @override
  State<ColleagueEditSalaryBottomSheet> createState() =>
      _ColleagueEditSalaryBottomSheetState();
}

class _ColleagueEditSalaryBottomSheetState
    extends State<ColleagueEditSalaryBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final List<_WageTypeFieldData> _wageTypeFields = [];
  bool _isInitializing = true;
  bool _isSaving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadWageTypes();
  }

  Future<void> _loadWageTypes() async {
    try {
      final workspaceRef = context.read<WorkspaceProvider>().workspaceRef;
      if (workspaceRef == null) {
        setState(() {
          _loadError = 'Nincs elérhető munkatér.';
          _isInitializing = false;
        });
        return;
      }

      final wageTypesSnapshot =
          await workspaceRef
              .collection('wageTypes')
              .orderBy('createdAt', descending: false)
              .get();

      final fields = <_WageTypeFieldData>[];
      final controllers = <String, TextEditingController>{};

      for (final wageTypeDoc in wageTypesSnapshot.docs) {
        final data = wageTypeDoc.data();
        final name = (data['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        final defaultValue = _toInt(data['defaultValue']);
        final customValueDoc =
            await wageTypeDoc.reference
                .collection('customValue')
                .doc(widget.colleague.id)
                .get();
        final customData = customValueDoc.data();
        final customValue = _tryToInt(
          customData?['value'] ?? customData?['customValue'],
        );
        final initialValue = customValue ?? defaultValue;

        fields.add(
          _WageTypeFieldData(
            wageTypeRef: wageTypeDoc.reference,
            name: name,
            initialValue: initialValue,
          ),
        );
        controllers[wageTypeDoc.id] = TextEditingController(
          text: initialValue.toString(),
        );
      }

      if (!mounted) return;
      setState(() {
        _wageTypeFields
          ..clear()
          ..addAll(fields);
        _controllers
          ..clear()
          ..addAll(controllers);
        _isInitializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Nem sikerült betölteni a bértípusokat.';
        _isInitializing = false;
      });
    }
  }

  int _toInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  int? _tryToInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveCustomValues() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isSaving = true);

      for (final field in _wageTypeFields) {
        final controller = _controllers[field.wageTypeRef.id];
        if (controller == null) continue;
        final currentValue = int.parse(controller.text.trim());

        if (currentValue == field.initialValue) continue;

        await field.wageTypeRef
            .collection('customValue')
            .doc(widget.colleague.id)
            .set({
              'uid': widget.colleague.id,
              'value': currentValue,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bér adatok sikeresen mentve')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mentési hiba történt'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Bérek módosítása',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.colleague.name}\n(${widget.colleague.email})',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (_isInitializing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadError != null)
              Text(
                _loadError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (_wageTypeFields.isEmpty)
              Text(
                'Nincs beállított bértípus a munkatérben.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ListView.separated(
                padding: EdgeInsets.symmetric(vertical: 16),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _wageTypeFields.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final field = _wageTypeFields[index];
                  return TextFormField(
                    controller: _controllers[field.wageTypeRef.id],
                    enabled: !_isSaving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: '${field.name} (Ft)',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final input = (value ?? '').trim();
                      if (input.isEmpty) return 'Add meg az értéket';
                      return null;
                    },
                  );
                },
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Mégse'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed:
                        _isSaving || _isInitializing || _wageTypeFields.isEmpty
                            ? null
                            : _saveCustomValues,
                    child:
                        _isSaving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Mentés'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WageTypeFieldData {
  const _WageTypeFieldData({
    required this.wageTypeRef,
    required this.name,
    required this.initialValue,
  });

  final DocumentReference<Map<String, dynamic>> wageTypeRef;
  final String name;
  final int initialValue;
}
