import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  String? _selectedProjectTypeId;
  List<Map<String, dynamic>> _projectTypes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWorkTypes();
  }

  Future<void> _loadWorkTypes() async {
    try {
      final types = await ProjectTypeService.getWorkTypesOnce();
      setState(() {
        _projectTypes = types;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Hiba történt az adatok betöltésekor: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Új projekt létrehozása')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Új projekt létrehozása')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          spacing: 16,
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Projekt neve',
                border: OutlineInputBorder(),
              ),
            ),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Megrendelő neve',
                border: OutlineInputBorder(),
              ),
            ),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Megrendelő telefonszáma',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Megrendelő email címe',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Helyszín',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.streetAddress,
            ),
            TextFormField(
              maxLines: 5,
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
                value: _selectedProjectTypeId,
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
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context),
        label: const Text('Mentés'),
        icon: const Icon(Icons.save),
      ),
    );
  }
}

class ProjectTypeService {
  static Future<List<Map<String, dynamic>>> getWorkTypesOnce() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('workTypes').get();

    return snapshot.docs.map((doc) {
      return {'id': doc.id, ...doc.data()};
    }).toList();
  }
}
