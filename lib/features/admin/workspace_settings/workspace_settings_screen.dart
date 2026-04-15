import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:okoskert_internal/app/workspace_provider.dart';
import 'package:provider/provider.dart';

class WorkspaceSettingsScreen extends StatefulWidget {
  const WorkspaceSettingsScreen({super.key});

  @override
  State<WorkspaceSettingsScreen> createState() =>
      _WorkspaceSettingsScreenState();
}

class _WorkspaceSettingsScreenState extends State<WorkspaceSettingsScreen> {
  Future<void> _showAddWageTypeSheet(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> workspaceRef,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WageTypeSheet(workspaceRef: workspaceRef),
    );
  }

  Future<void> _showEditWageTypeSheet(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> workspaceRef,
    QueryDocumentSnapshot<Map<String, dynamic>> wageTypeDoc,
  ) async {
    final data = wageTypeDoc.data();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => _WageTypeSheet(
            workspaceRef: workspaceRef,
            wageTypeRef: wageTypeDoc.reference,
            initialName: data['name'] as String? ?? '',
            initialDefaultValue: data['defaultValue']?.toString() ?? '',
          ),
    );
  }

  Future<void> _showEditWorkspaceSheet(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> workspaceRef,
    String currentName,
    String currentLocation,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => _EditWorkspaceSheet(
            workspaceRef: workspaceRef,
            currentName: currentName,
            currentLocation: currentLocation,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspaceRef = context.watch<WorkspaceProvider>().workspaceRef;

    return Scaffold(
      appBar: AppBar(title: const Text('Munkatér beállítások')),
      body:
          workspaceRef == null
              ? const Center(child: Text('Nincs elérhető munkatér.'))
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: workspaceRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Nem sikerült betölteni a munkatér adatait.'),
                    );
                  }

                  final workspaceData = snapshot.data?.data() ?? {};
                  final workspaceName =
                      workspaceData['name'] as String? ?? 'Névtelen munkatér';
                  final workspaceLocation =
                      workspaceData['address'] as String? ?? '';

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream:
                        workspaceRef
                            .collection('wageTypes')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                    builder: (context, wageTypesSnapshot) {
                      if (wageTypesSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (wageTypesSnapshot.hasError) {
                        return const Center(
                          child: Text(
                            'Nem sikerült betölteni a bér típusokat.',
                          ),
                        );
                      }

                      final wageTypes = wageTypesSnapshot.data?.docs ?? [];

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Munkatér adatok',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed:
                                    () => _showEditWorkspaceSheet(
                                      context,
                                      workspaceRef,
                                      workspaceName,
                                      workspaceLocation,
                                    ),
                                icon: const Icon(Icons.edit),
                                label: const Text('Szerkesztés'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.business),
                              title: Text(workspaceName),
                              subtitle: Text(
                                workspaceLocation.isEmpty
                                    ? 'Helyszín: nincs megadva'
                                    : 'Helyszín: $workspaceLocation',
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Bér típusok',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed:
                                    () => _showAddWageTypeSheet(
                                      context,
                                      workspaceRef,
                                    ),
                                icon: const Icon(Icons.add),
                                label: const Text('Új típus'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (wageTypes.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Még nincs felvett bér típus.'),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: wageTypes.length,
                              separatorBuilder:
                                  (_, __) => const Divider(height: 0),
                              itemBuilder: (context, index) {
                                final doc = wageTypes[index];
                                final data = doc.data();
                                final name =
                                    data['name'] as String? ?? 'Névtelen';
                                final defaultValue =
                                    data['defaultValue']?.toString();

                                return InkWell(
                                  onTap:
                                      () => _showEditWageTypeSheet(
                                        context,
                                        workspaceRef,
                                        doc,
                                      ),
                                  child: ListTile(
                                    title: Text(name),
                                    subtitle: Text(
                                      'Alapértelmezett érték: ${defaultValue ?? '-'}',
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
    );
  }
}

class _WageTypeSheet extends StatefulWidget {
  const _WageTypeSheet({
    required this.workspaceRef,
    this.wageTypeRef,
    this.initialName = '',
    this.initialDefaultValue = '',
  });

  final DocumentReference<Map<String, dynamic>> workspaceRef;
  final DocumentReference<Map<String, dynamic>>? wageTypeRef;
  final String initialName;
  final String initialDefaultValue;

  bool get isEditMode => wageTypeRef != null;

  @override
  State<_WageTypeSheet> createState() => _WageTypeSheetState();
}

class _WageTypeSheetState extends State<_WageTypeSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _defaultValueController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _defaultValueController = TextEditingController(
      text: widget.initialDefaultValue,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _defaultValueController.dispose();
    super.dispose();
  }

  Future<void> _saveWageType() async {
    final name = _nameController.text.trim();
    final defaultValueText = _defaultValueController.text.trim();
    final defaultValue = int.tryParse(defaultValueText);

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Adj meg egy nevet.')));
      return;
    }

    if (defaultValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Az alapértelmezett érték csak szám lehet.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (widget.isEditMode) {
        await widget.wageTypeRef!.update({
          'name': name,
          'defaultValue': defaultValue,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await widget.workspaceRef.collection('wageTypes').add({
          'name': name,
          'defaultValue': defaultValue,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditMode ? 'Bér típus frissítve.' : 'Bér típus mentve.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hiba történt mentés közben.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteWageType() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Bér típus törlése'),
            content: const Text('Biztosan törölni szeretnéd ezt a bér típust?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Mégse'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Törlés'),
              ),
            ],
          ),
    );

    if (shouldDelete != true) return;

    setState(() => _isSaving = true);
    try {
      await widget.wageTypeRef!.delete();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bér típus törölve.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hiba történt törlés közben.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.isEditMode ? 'Bér típus szerkesztése' : 'Új bér típus',
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
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Név',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _defaultValueController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Alapértelmezett érték',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            spacing: 8,
            children: [
              if (widget.isEditMode) ...[
                IconButton.outlined(
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed: _isSaving ? null : _deleteWageType,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isSaving ? null : _saveWageType,
                  icon:
                      _isSaving
                          ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : null,
                  label: const Text('Mentés'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditWorkspaceSheet extends StatefulWidget {
  const _EditWorkspaceSheet({
    required this.workspaceRef,
    required this.currentName,
    required this.currentLocation,
  });

  final DocumentReference<Map<String, dynamic>> workspaceRef;
  final String currentName;
  final String currentLocation;

  @override
  State<_EditWorkspaceSheet> createState() => _EditWorkspaceSheetState();
}

class _EditWorkspaceSheetState extends State<_EditWorkspaceSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _locationController = TextEditingController(text: widget.currentLocation);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveWorkspaceData() async {
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A munkatér neve kötelező.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.workspaceRef.update({'name': name, 'location': location});

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Munkatér adatok mentve.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hiba történt mentés közben.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Munkatér adatok',
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
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Munkatér neve',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Helyszín',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isSaving ? null : _saveWorkspaceData,
              icon:
                  _isSaving
                      ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : null,
              label: const Text('Mentés'),
            ),
          ),
        ],
      ),
    );
  }
}
