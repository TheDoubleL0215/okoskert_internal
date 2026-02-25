import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  DateTime _selectedDate = DateTime.now();
  late TextEditingController _dateController;
  num _currentWorkHours = 0;
  bool _isLoadingCurrentHours = true;
  bool _isProjectEnabled = false;
  String? _selectedProjectId;
  List<Map<String, String>> _projects = [];

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: _formatDate(_selectedDate));
    _loadCurrentWorkHours();
    _loadProjects();
  }

  @override
  void dispose() {
    _newHoursController.dispose();
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
        setState(() {
          _isLoadingCurrentHours = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoadingCurrentHours = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hiba történt az adatok betöltésekor: $error'),
          ),
        );
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

  String _formatHours(num value) {
    final asDouble = value.toDouble();
    return asDouble % 1 == 0
        ? asDouble.toInt().toString()
        : asDouble.toStringAsFixed(1);
  }

  double? _parseHours(String raw) {
    return double.tryParse(raw.trim().replaceAll(',', '.'));
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

    try {
      final newHours = _parseHours(_newHoursController.text) ?? 0.0;

      await MachineWorkHoursService.saveWorkHours(
        machineId: widget.machineId,
        newHours: newHours,
        date: _selectedDate,
        previousHours: _currentWorkHours,
        projectEnabled: _selectedProjectId != null,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        child: Padding(
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
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
                  decoration: InputDecoration(
                    labelText: 'Dátum',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: _selectDate,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    spacing: 8,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _HoursValue(
                        label: 'Jelenlegi',
                        value:
                            _isLoadingCurrentHours
                                ? 'Betöltés...'
                                : '${_formatHours(_currentWorkHours)} óra',
                      ),
                      Icon(Icons.arrow_downward_rounded),
                      SizedBox(
                        width: 120,
                        child: TextFormField(
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          textAlign: TextAlign.center,
                          controller: _newHoursController,
                          decoration: InputDecoration(
                            labelText: 'Új óraállás',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            errorMaxLines: 3,
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nincs érték megadva!';
                            }
                            final parsedValue = _parseHours(value);
                            if (parsedValue == null) {
                              return 'Nem érvényes szám!';
                            }
                            if (parsedValue <= _currentWorkHours) {
                              return 'Túl alacsony érték!';
                            }
                            if ((parsedValue - _currentWorkHours).abs() > 10) {
                              return 'Max. 10 óra különbség lehet!';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // State változók - a switch helyett csak ezt tartsd meg:
                // String? _selectedProjectId;  <- ezt már van
                // A _isProjectEnabled-t törölheted, mert már nem kell

                // A projekt box:
                InkWell(
                  onTap: _showProjectDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Projekt',
                                style: Theme.of(
                                  context,
                                ).textTheme.labelSmall?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                _selectedProjectId == null
                                    ? 'Nincs kiválasztva'
                                    : _projects.firstWhere(
                                      (p) => p['id'] == _selectedProjectId,
                                    )['name']!,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: SlideAction(
                    sliderRotate: false,
                    innerColor: Theme.of(context).colorScheme.surfaceContainer,
                    outerColor: Theme.of(context).colorScheme.primary,
                    onSubmit: _saveWorkHours,
                    child: Text(
                      'Óraállás rögzítése',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showProjectDialog() async {
    String? tempSelected = _selectedProjectId;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              insetPadding: EdgeInsets.zero,
              title: const Text('Projekt kiválasztása'),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              contentPadding: EdgeInsets.zero,
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // "None" option
                          RadioListTile<String?>(
                            title: const Text('Nincs'),
                            value: null,
                            groupValue: tempSelected,
                            // Ensure you use the specific type in the callback
                            onChanged: (String? value) {
                              setDialogState(() => tempSelected = value);
                            },
                          ),
                          // Project options
                          ..._projects.map((project) {
                            return RadioListTile<String?>(
                              title: Text(project['name']!),
                              value: project['id'],
                              groupValue: tempSelected,
                              onChanged: (String? value) {
                                setDialogState(() => tempSelected = value);
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Mégse'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _selectedProjectId = tempSelected);
                    Navigator.pop(context);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
  }
}

class _HoursValue extends StatelessWidget {
  final String label;
  final String value;
  final String? helper;

  const _HoursValue({required this.label, required this.value, this.helper});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 2),
          Text(
            helper!,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }
}
