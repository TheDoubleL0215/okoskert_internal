import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CreateNewWorkspaceScreen extends StatefulWidget {
  final String? signupName;
  final String? signupEmail;
  final String? signupPassword;

  const CreateNewWorkspaceScreen({
    super.key,
    this.signupName,
    this.signupEmail,
    this.signupPassword,
  });
  const CreateNewWorkspaceScreen.forSignup({
    super.key,
    required this.signupName,
    required this.signupEmail,
    required this.signupPassword,
  });

  @override
  State<CreateNewWorkspaceScreen> createState() =>
      _CreateNewWorkspaceScreenState();
}

class _CreateNewWorkspaceScreenState extends State<CreateNewWorkspaceScreen> {
  static const String _createWorkspaceUrl =
      'https://us-central1-okoskert-dev.cloudfunctions.net/createWorkspace';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String _generateTeamId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  Future<void> _createWorkspace() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;

      final signupEmail = widget.signupEmail?.trim();
      final signupPassword = widget.signupPassword;
      final signupName = widget.signupName?.trim() ?? '';

      if (user == null && signupEmail != null && signupEmail.isNotEmpty) {
        user =
            (await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: signupEmail,
              password: signupPassword ?? '',
            )).user;
      }

      if (user == null) {
        setState(() {
          _errorMessage = 'Nincs bejelentkezett felhasználó';
        });
        return;
      }

      // Generáljuk a teamId-t
      final teamId = _generateTeamId();

      final emailForRequest = user.email ?? signupEmail ?? '';
      if (emailForRequest.isEmpty) {
        setState(() {
          _errorMessage = 'Nem található email cím a workspace létrehozásához';
        });
        return;
      }

      // Workspace létrehozása Cloud Functionnel
      final workspaceBody = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'teamId': teamId,
        'createdAt': DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse(
          _createWorkspaceUrl,
        ).replace(queryParameters: {'email': emailForRequest}),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(workspaceBody),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Workspace létrehozás sikertelen: ${response.body}');
      }

      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final userDoc = await userDocRef.get();

      if (userDoc.exists) {
        await userDocRef.update({
          'teamId': teamId,
          'role': 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await userDocRef.set({
          'name':
              signupName.isNotEmpty
                  ? signupName
                  : (user.displayName?.trim().isNotEmpty == true
                      ? user.displayName!.trim()
                      : user.email ?? ''),
          'email': user.email ?? signupEmail ?? '',
          'role': 1,
          'teamId': teamId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      setState(() {
        _successMessage = 'Munkahely sikeresen létrehozva!';
      });
      Navigator.pop(context);

      // Sikeres mentés után a main.dart StreamBuilder automatikusan átvált a HomePage-re
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Hiba történt a mentéskor: $error';
      });
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
    return Scaffold(
      appBar: AppBar(title: const Text('Új munkahely létrehozása')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Munkahely neve',
                    hintText: 'Add meg a munkahely nevét',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'A munkahely neve kötelező';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  keyboardType: TextInputType.streetAddress,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Munkahely címe',
                    hintText: 'Add meg a munkahely címét',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'A munkahely címe kötelező';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_successMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: TextStyle(color: Colors.green.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _createWorkspace,
                    child:
                        _isSaving
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Text(
                              'Munkahely létrehozása',
                              style: TextStyle(fontSize: 16),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
