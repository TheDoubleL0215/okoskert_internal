import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/services/project_type_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool _isInitializing = false;
  String? _message;

  Future<void> _initializeProjectTypes() async {
    setState(() {
      _isInitializing = true;
      _message = null;
    });

    try {
      await ProjectTypeService.initializeProjectTypes();
      if (mounted) {
        setState(() {
          _message = 'Projekt típusok sikeresen inicializálva!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Hiba történt: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Admin')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: [
            FilledButton.icon(
              onPressed: _isInitializing ? null : _initializeProjectTypes,
              icon:
                  _isInitializing
                      ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : Icon(Icons.cloud_upload),
              label: Text('Projekt típusok inicializálása'),
            ),
            if (_message != null)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      _message!.contains('Hiba')
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        _message!.contains('Hiba')
                            ? Colors.red.shade300
                            : Colors.green.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _message!.contains('Hiba')
                          ? Icons.error
                          : Icons.check_circle,
                      color:
                          _message!.contains('Hiba')
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color:
                              _message!.contains('Hiba')
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 32),
            FilledButton(
              onPressed: () {
                FirebaseAuth.instance.signOut();
              },
              child: Text('Kijelentkezés'),
            ),
          ],
        ),
      ),
    );
  }
}
