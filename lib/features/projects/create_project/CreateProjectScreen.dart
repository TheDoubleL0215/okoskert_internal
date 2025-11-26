import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:okoskert_internal/data/services/project_types_query.dart';
import 'package:okoskert_internal/data/services/get_project_by_id.dart';

class CreateProjectScreen extends StatefulWidget {
  final String? projectId;

  const CreateProjectScreen({super.key, this.projectId});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _selectedProjectTypeId;
  List<Map<String, dynamic>> _projectTypes = [];
  bool _isLoading = true;
  bool _isMaintenance = false;
  String? _error;

  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _customerEmailController =
      TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // First load work types, then load project data if needed
    await _loadWorkTypes();
    if (widget.projectId != null) {
      await _loadProjectData();
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadWorkTypes() async {
    try {
      final types = await ProjectTypeService.getWorkTypesOnce();
      setState(() {
        _projectTypes = types;
      });
    } catch (e) {
      setState(() {
        _error = 'Hiba történt az adatok betöltésekor: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProjectData() async {
    if (widget.projectId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final projectData = await ProjectService.getProjectById(
        widget.projectId!,
      );
      if (projectData == null) {
        setState(() {
          _error = 'A projekt nem található';
          _isLoading = false;
        });
        return;
      }

      // Fill controllers with project data
      _nameController.text = projectData['projectName'] ?? '';
      _customerNameController.text = projectData['customerName'] ?? '';

      // Handle phone number - remove +36 prefix if present
      String phone = projectData['customerPhone'] ?? '';
      if (phone.startsWith('+36')) {
        phone = phone.substring(3);
      }
      _customerPhoneController.text = phone;

      _customerEmailController.text = projectData['customerEmail'] ?? '';
      _locationController.text = projectData['projectLocation'] ?? '';
      _descriptionController.text = projectData['projectDescription'] ?? '';

      // Set maintenance status
      final status = projectData['projectStatus'] as String?;
      _isMaintenance = status == 'maintenance';

      // Find and set project type ID (now _projectTypes should be loaded)
      final projectTypeName = projectData['projectType'] as String?;
      if (projectTypeName != null && _projectTypes.isNotEmpty) {
        final type = _projectTypes.firstWhere(
          (type) => type['name'] == projectTypeName,
          orElse: () => <String, dynamic>{},
        );
        if (type.isNotEmpty) {
          _selectedProjectTypeId = type['id'] as String?;
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Hiba történt a projekt betöltésekor: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.projectId != null;
    final appBarTitle =
        isEditMode ? 'Projekt szerkesztése' : 'Új projekt létrehozása';

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            appBarTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: FilledButton(
              onPressed: _saveProject,
              child: const Text('Mentés'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8.0),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            spacing: 16,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Projekt neve',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'A projekt neve kötelező';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _customerNameController,
                decoration: const InputDecoration(
                  labelText: 'Megrendelő neve',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'A megrendelő neve kötelező';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _customerPhoneController,
                decoration: InputDecoration(
                  labelText: 'Megrendelő telefonszáma',
                  border: const OutlineInputBorder(),
                  prefixText: '+36 ',
                  prefixStyle: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return null; // opcionális
                  final phoneReg = RegExp(r'^[0-9+()\-\s]{6,}$');
                  if (!phoneReg.hasMatch(v)) {
                    return 'Érvénytelen telefonszám formátum';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _customerEmailController,
                decoration: const InputDecoration(
                  labelText: 'Megrendelő email címe',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return null; // opcionális
                  final emailReg = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                  if (!emailReg.hasMatch(v)) {
                    return 'Érvénytelen email cím';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Helyszín',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.streetAddress,
              ),
              TextFormField(
                maxLines: 5,
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Leírás',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.multiline,
              ),

              // Dropdown for project type
              if (_error != null)
                DropdownButtonFormField<String>(
                  items: const [],
                  onChanged: null,
                  decoration: InputDecoration(
                    labelText: 'Projekt típusa',
                    border: OutlineInputBorder(),
                    errorText: 'Hiba történt az adatok betöltésekor',
                  ),
                )
              else if (_projectTypes.isEmpty)
                DropdownButtonFormField<String>(
                  items: [],
                  onChanged: null,
                  decoration: InputDecoration(
                    labelText: 'Projekt típusa',
                    border: OutlineInputBorder(),
                    hintText: 'Nincsenek elérhető típusok',
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedProjectTypeId,
                  decoration: const InputDecoration(
                    labelText: 'Projekt típusa',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      _projectTypes.map((type) {
                        final id = type['id'] as String;
                        final name = type['name'] as String;
                        return DropdownMenuItem(value: id, child: Text(name));
                      }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedProjectTypeId = value);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Válassz projekt típust';
                    }
                    return null;
                  },
                ),

              ListTile(
                leading: Switch(
                  value: _isMaintenance,
                  onChanged: (bool value) {
                    setState(() {
                      _isMaintenance = value;
                    });
                  },
                ),
                title: const Text('Karbantartás'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProject() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ellenőrizd az űrlap hibáit')),
      );
      return;
    }

    // Find the selected project type name
    final selectedType = _projectTypes.firstWhere(
      (type) => type['id'] == _selectedProjectTypeId,
      orElse: () => <String, dynamic>{},
    );
    final projectTypeName = selectedType['name'] as String? ?? '';

    final Map<String, dynamic> data = {
      'projectName': _nameController.text.trim(),
      'customerName': _customerNameController.text.trim(),
      'customerPhone':
          _customerPhoneController.text.trim().isNotEmpty
              ? "+36${_customerPhoneController.text.trim()}"
              : null,
      'customerEmail':
          _customerEmailController.text.trim().isNotEmpty
              ? _customerEmailController.text.trim()
              : null,
      'projectLocation':
          _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
      'projectDescription':
          _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
      'projectType': projectTypeName,
      'projectStatus': _isMaintenance ? 'maintenance' : 'ongoing',
    };

    debugPrint(jsonEncode(data));
    try {
      if (widget.projectId != null) {
        // Update existing project
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .update(data);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Projekt sikeresen frissítve')),
        );
      } else {
        // Create new project
        await FirebaseFirestore.instance.collection('projects').add(data);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Projekt sikeresen elmentve')),
        );
      }
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba történt a mentéskor: $error')),
      );
    }
  }
}
