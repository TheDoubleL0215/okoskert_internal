import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';

class CreateMachineScreen extends StatefulWidget {
  const CreateMachineScreen({super.key});

  @override
  State<CreateMachineScreen> createState() => _CreateMachineScreenState();
}

class _CreateMachineScreenState extends State<CreateMachineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameFieldKey = GlobalKey<FormFieldState<String>>();
  final _nameController = TextEditingController();
  final _hoursController = TextEditingController();
  final _tmkMaintenanceHoursController = TextEditingController();

  /// Ha már egyszer megnyomták a mentést, utána minden mezőn megjelennek a validációs hibák.
  bool _didAttemptSubmit = false;

  // Karbantartások kezelése
  final List<Map<String, TextEditingController>> _maintenances = [];

  @override
  void dispose() {
    _nameController.dispose();
    _hoursController.dispose();
    _tmkMaintenanceHoursController.dispose();
    // Dispose all maintenance controllers
    for (var maintenance in _maintenances) {
      maintenance['name']?.dispose();
      maintenance['hours']?.dispose();
    }
    super.dispose();
  }

  void _addMaintenance() {
    setState(() {
      _maintenances.add({
        'name': TextEditingController(),
        'hours': TextEditingController(),
      });
    });
  }

  Future<void> _saveMachine() async {
    final name = _nameController.text.trim();
    final hours = double.tryParse(_hoursController.text.trim()) ?? 0.0;
    final tmkMaintenanceHours =
        double.tryParse(_tmkMaintenanceHoursController.text.trim()) ?? 0.0;

    if (tmkMaintenanceHours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A TMK karbantartás gyakorisága nem lehet 0 vagy üres'),
        ),
      );
      return;
    }
    for (var maintenance in _maintenances) {
      final maintenanceHours =
          double.tryParse(maintenance['hours']?.text.trim() ?? '0.0') ?? 0.0;

      if (maintenanceHours <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A karbantartás óránkénti értéke nem lehet 0 vagy negatív',
            ),
          ),
        );
        return; // This now correctly exits the entire _saveMachine function
      }
    }
    final maintenances =
        _maintenances
            .where(
              (maintenance) =>
                  maintenance['name']?.text.trim().isNotEmpty ?? false,
            )
            .map((maintenance) {
              final maintenanceHours =
                  double.tryParse(maintenance['hours']?.text.trim() ?? '0.0') ??
                  0.0;
              return {
                'name': maintenance['name']?.text.trim(),
                'interval':
                    double.tryParse(
                      maintenance['hours']?.text.trim() ?? '0.0',
                    ) ??
                    0.0,
                "lastAt":
                    hours <= 0
                        ? 0
                        : (hours / maintenanceHours).floor() * maintenanceHours,
              };
            })
            .toList();
    maintenances.add({
      "name": "TMK karbantartás",
      "interval": tmkMaintenanceHours,
      "lastAt":
          hours <= 0
              ? 0
              : (hours / tmkMaintenanceHours).floor() * tmkMaintenanceHours,
    });
    try {
      await FirebaseFirestore.instance.collection('machines').add({
        'teamId': await UserService.getTeamId(),
        'name': name,
        'hours': hours,
        'maintenances': maintenances,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gép sikeresen mentve')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba történt a mentéskor: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gép hozzáadása')),
      body: Form(
        key: _formKey,
        autovalidateMode:
            _didAttemptSubmit
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              spacing: 16,
              children: [
                TextFormField(
                  key: _nameFieldKey,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Gép neve nem lehet üres';
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.sentences,
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Gép neve',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextFormField(
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Óraállás nem lehet üres';
                    }
                    if (double.tryParse(value.trim()) == null) {
                      return 'Érvénytelen szám';
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.number,
                  controller: _hoursController,
                  decoration: const InputDecoration(
                    labelText: 'Óraállás',
                    border: OutlineInputBorder(),
                  ),
                ),
                Divider(),
                Text(
                  'Karbantartások',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Expanded(child: Text('TMK karbantartás')),
                      Expanded(
                        child: TextField(
                          controller: _tmkMaintenanceHoursController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Óránként',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.all(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                // Karbantartások listája
                ..._maintenances.map((maintenance) {
                  final nameController = maintenance['name']!;
                  final hoursController = maintenance['hours']!;
                  final index = _maintenances.indexOf(maintenance);

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Karbantartás neve',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.all(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: hoursController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Óránként',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.all(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            setState(() {
                              nameController.dispose();
                              hoursController.dispose();
                              _maintenances.removeAt(index);
                            });
                          },
                          tooltip: 'Törlés',
                        ),
                      ],
                    ),
                  );
                }).toList(),
                FilledButton.tonalIcon(
                  onPressed: _addMaintenance,
                  icon: const Icon(Icons.add),
                  label: const Text('Karbantartás hozzáadása'),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: () {
            setState(() => _didAttemptSubmit = true);
            final isValid = _formKey.currentState!.validate();
            if (isValid) {
              _saveMachine();
            } else {
              // Görgetés az első mezőhöz, hogy látsódjon a hiba
              final ctx = _nameFieldKey.currentContext;
              if (ctx != null) {
                Scrollable.ensureVisible(
                  ctx,
                  alignment: 0.1,
                  duration: const Duration(milliseconds: 300),
                );
              }
            }
          },
          child: const Text('Gép mentése'),
        ),
      ),
    );
  }
}
