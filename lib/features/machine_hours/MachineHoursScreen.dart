import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okoskert_internal/features/machine_hours/MachineDetailsScreen.dart';

class MachineHoursScreen extends StatefulWidget {
  const MachineHoursScreen({super.key});

  @override
  State<MachineHoursScreen> createState() => _MachineHoursScreenState();
}

class _MachineHoursScreenState extends State<MachineHoursScreen> {
  void _showAddMachineModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddMachineBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Üzemóra állás')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection('machines')
                .orderBy('name')
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Hiba történt az adatok betöltésekor: ${snapshot.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final machineDocs = snapshot.data?.docs ?? [];

          if (machineDocs.isEmpty) {
            return const Center(
              child: Text(
                'Még nincsenek gépek',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView.separated(
              itemCount: machineDocs.length,
              itemBuilder: (context, index) {
                final doc = machineDocs[index];
                final data = doc.data();
                final name = data['name'] as String? ?? 'Ismeretlen';
                final hours = data['hours'] as num? ?? 0;

                return ListTile(
                  leading: Hero(
                    tag: doc.id,
                    child: CircleAvatar(child: const Icon(Icons.agriculture)),
                  ),
                  title: Text(name),
                  subtitle: Text('Óraállás: $hours'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => MachineDetailsScreen(
                              machineValue: hours.toString(),
                              machineName: name,
                              machineId: doc.id,
                            ),
                      ),
                    );
                  },
                );
              },
              separatorBuilder: (context, index) => const Divider(),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMachineModal,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddMachineBottomSheet extends StatefulWidget {
  const AddMachineBottomSheet({super.key});

  @override
  State<AddMachineBottomSheet> createState() => _AddMachineBottomSheetState();
}

class _AddMachineBottomSheetState extends State<AddMachineBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hoursController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _saveMachine() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final name = _nameController.text.trim();
      final hours = double.tryParse(_hoursController.text.trim()) ?? 0.0;

      await FirebaseFirestore.instance.collection('machines').add({
        'name': name,
        'hours': hours,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gép sikeresen hozzáadva')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba történt a mentéskor: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Új gép hozzáadása',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Név',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Kérjük, adja meg a nevet';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hoursController,
              decoration: const InputDecoration(
                labelText: 'Óraállás',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Kérjük, adja meg az óraállást';
                }
                if (double.tryParse(value.trim()) == null) {
                  return 'Kérjük, érvényes számot adjon meg';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveMachine,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child:
                  _isSaving
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Mentés'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
