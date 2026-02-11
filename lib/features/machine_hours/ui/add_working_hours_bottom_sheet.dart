import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/core/utils/services/machine_work_hours_service.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:slide_to_act/slide_to_act.dart';

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
        _currentWorkHours = data?['hours'] as num? ?? 0;
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
          await FirebaseFirestore.instance
              .collection('projects')
              .where('teamId', isEqualTo: await UserService.getTeamId())
              .get();

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
    setState(() {
      _isSaving = true;
    });

    try {
      final newHours = double.tryParse(_newHoursController.text.trim()) ?? 0.0;

      await MachineWorkHoursService.saveWorkHours(
        machineId: widget.machineId,
        newHours: newHours,
        date: _selectedDate,
        previousHours: _currentWorkHours,
        projectEnabled: _isProjectEnabled,
        assignedProjectId: _selectedProjectId,
      );

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
                if (value.isNotEmpty &&
                    double.tryParse(value.trim())! <= _currentWorkHours) {
                  return 'Az új óraállás nem lehet kisebb, mint a jelenlegi óraállás';
                }
                if (value.isNotEmpty &&
                    (double.tryParse(value.trim())! - _currentWorkHours).abs() >
                        10) {
                  return 'Az új óraállás nem lehet nagyobb, mint 10 óra';
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
            SizedBox(
              width: double.infinity,
              child: SlideAction(
                sliderRotate: false,
                outerColor: Theme.of(context).colorScheme.primary,
                onSubmit: _saveWorkHours,
                child: Text(
                  'Mentés',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
