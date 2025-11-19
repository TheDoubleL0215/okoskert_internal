import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddWorkHoursBottomSheet extends StatefulWidget {
  final String machineId;
  const AddWorkHoursBottomSheet({super.key, required this.machineId});

  @override
  State<AddWorkHoursBottomSheet> createState() =>
      _AddWorkHoursBottomSheetState();
}

class _AddWorkHoursBottomSheetState extends State<AddWorkHoursBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _newHoursController = TextEditingController();
  final _currentHoursController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  late TextEditingController _dateController;
  num _currentWorkHours = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isProjectEnabled = false;
  String? _selectedProjectId;
  List<Map<String, String>> _projects = [];

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: _formatDate(_selectedDate));
    _currentHoursController.text = 'Betöltés...';
    _loadCurrentWorkHours();
    _loadProjects();
  }

  @override
  void dispose() {
    _newHoursController.dispose();
    _currentHoursController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentWorkHours() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('machines')
              .doc(widget.machineId)
              .get();

      if (doc.exists) {
        final data = doc.data();
        // Először próbáljuk a workHours mezőt, ha nincs, akkor a hours mezőt
        _currentWorkHours =
            data?['workHours'] as num? ?? data?['hours'] as num? ?? 0;
      }
      if (mounted) {
        _currentHoursController.text = _currentWorkHours.toString();
      }
    } catch (error) {
      if (mounted) {
        _currentHoursController.text = 'Hiba';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hiba történt az adatok betöltésekor: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadProjects() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('projects').get();

      if (mounted) {
        setState(() {
          _projects =
              snapshot.docs.map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'name': data['projectName'] as String? ?? 'Névtelen projekt',
                };
              }).toList();
          // Rendezés név szerint
          _projects.sort((a, b) => a['name']!.compareTo(b['name']!));
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hiba történt a projektek betöltésekor: $error'),
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}. ${date.month.toString().padLeft(2, '0')}. ${date.day.toString().padLeft(2, '0')}.';
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _dateController.text = _formatDate(_selectedDate);
      });
    }
  }

  Future<void> _saveWorkHours() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validáció: ha projekt be van kapcsolva, akkor ki kell választani egy projektet
    if (_isProjectEnabled && _selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Válassz ki egy projektet!')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final newHours = double.tryParse(_newHoursController.text.trim()) ?? 0.0;

      final workHoursData = {
        'date': Timestamp.fromDate(_selectedDate),
        'previousHours': _currentWorkHours,
        'newHours': newHours,
        'machineId': widget.machineId,
        'createdAt': FieldValue.serverTimestamp(),
        if (_isProjectEnabled) 'assignedProjectId': _selectedProjectId,
      };

      // Mentés a workHoursLog kollekcióba
      await FirebaseFirestore.instance
          .collection('machines')
          .doc(widget.machineId)
          .collection('workHoursLog')
          .add(workHoursData);

      // Ha projekt ki van választva, mentjük a projekt machineWorklog kollekciójába is
      if (_isProjectEnabled && _selectedProjectId != null) {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(_selectedProjectId)
            .collection('machineWorklog')
            .add(workHoursData);
      }

      // Frissítjük a gép jelenlegi óraállását is
      await FirebaseFirestore.instance
          .collection('machines')
          .doc(widget.machineId)
          .update({
            'workHours': newHours,
            'hours': newHours, // Kompatibilitás miatt is frissítjük
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Óraállás sikeresen mentve')),
      );
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
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'Óraállás hozzáadása',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Dátum választó
            TextFormField(
              controller: _dateController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Dátum',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: _selectDate,
            ),
            const SizedBox(height: 16),
            // Jelenlegi óraállás (nem szerkeszthető)
            TextFormField(
              controller: _currentHoursController,
              readOnly: true,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Jelenlegi óraállás',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Új óraállás (szerkeszthető)
            TextFormField(
              controller: _newHoursController,
              decoration: const InputDecoration(
                labelText: 'Új óraállás',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Kérjük, adja meg az új óraállást';
                }
                if (double.tryParse(value.trim()) == null) {
                  return 'Kérjük, érvényes számot adjon meg';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Projekt switch
            ListTile(
              leading: Switch(
                value: _isProjectEnabled,
                onChanged: (value) {
                  setState(() {
                    _isProjectEnabled = value;
                    if (!value) {
                      _selectedProjectId = null;
                    }
                  });
                },
              ),
              title: const Text('Projekt'),
            ),
            // Projekt dropdown (csak ha a switch be van kapcsolva)
            if (_isProjectEnabled) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedProjectId,
                decoration: const InputDecoration(
                  labelText: 'Projekt kiválasztása',
                  border: OutlineInputBorder(),
                ),
                items:
                    _projects.map((project) {
                      return DropdownMenuItem<String>(
                        value: project['id'],
                        child: Text(project['name']!),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedProjectId = value;
                  });
                },
                validator: (value) {
                  if (_isProjectEnabled && value == null) {
                    return 'Kérjük, válasszon ki egy projektet';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving || _isLoading ? null : _saveWorkHours,
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
                      : const Text(
                        'Mentés',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
