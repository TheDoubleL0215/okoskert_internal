import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:okoskert_internal/core/utils/login_error_messages.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _accessCodeController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedMode = 'Bejelentkezés';
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _accessCodeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      if (_selectedMode == 'Bejelentkezés') {
        // Bejelentkezés
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        // Sikeres bejelentkezés után az AuthGate automatikusan átvált a HomePage-re
      } else {
        // Regisztráció
        final accessCode = _accessCodeController.text.trim();

        // Ha a hozzáférési kód "CNWS", navigáljunk a CreateNewWorkspaceScreen-re
        if (accessCode == 'CNWS') {
          final userCredential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
                email: _emailController.text.trim(),
                password: _passwordController.text,
              );
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
                'name': _nameController.text.trim(),
                'email': _emailController.text.trim(),
                'role': 1,
                'createdAt': FieldValue.serverTimestamp(),
              });
          if (!mounted) return;
          setState(() {
            _nameController.clear();
            _emailController.clear();
            _passwordController.clear();
            _confirmPasswordController.clear();
            _accessCodeController.clear();
          });
          return;
        }

        // Ellenőrizzük, hogy a hozzáférési kód egy workspace teamId-e
        final workspaceQuery =
            await FirebaseFirestore.instance
                .collection('workspaces')
                .where('teamId', isEqualTo: accessCode)
                .limit(1)
                .get();
        if (workspaceQuery.docs.isNotEmpty) {
          final userCredential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
                email: _emailController.text.trim(),
                password: _passwordController.text,
              );
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
                'name': _nameController.text.trim(),
                'email': _emailController.text.trim(),
                'teamId': accessCode,
                'createdAt': FieldValue.serverTimestamp(),
              });
          // Ha van egyező workspace, hozzáadjuk a joinRequest-et
          final workspaceDoc = workspaceQuery.docs.first;
          await workspaceDoc.reference.collection('joinRequests').add({
            'userId': userCredential.user!.uid,
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'pending',
          });

          if (!mounted) return;
          setState(() {
            _successMessage = 'Csatlakozási kérés sikeresen elküldve!';
            _nameController.clear();
            _emailController.clear();
            _passwordController.clear();
            _confirmPasswordController.clear();
            _accessCodeController.clear();
          });
          return;
        }

        if (!mounted) return;
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = getLoginErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Váratlan hiba történt. Kérjük, próbáld újra.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRegisterMode = _selectedMode == 'Regisztráció';

    return Scaffold(
      appBar: AppBar(title: Text(_selectedMode)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'Bejelentkezés',
                      label: Text('Bejelentkezés'),
                    ),
                    ButtonSegment(
                      value: 'Regisztráció',
                      label: Text('Regisztráció'),
                    ),
                  ],
                  selected: {_selectedMode},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _selectedMode = newSelection.first;
                      _errorMessage = null;
                      _successMessage = null;
                    });
                  },
                ),
                const SizedBox(height: 24),
                if (isRegisterMode) ...[
                  TextFormField(
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Név',
                      hintText: 'Add meg a neved',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Kérjük, add meg a neved';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Add meg az email címed',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Kérjük, add meg az email címed';
                    }
                    if (!value.contains('@')) {
                      return 'Kérjük, érvényes email címet adj meg';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Jelszó',
                    hintText: 'Add meg a jelszavad',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Kérjük, add meg a jelszavad';
                    }
                    if (value.length < 6) {
                      return 'A jelszó legalább 6 karakter hosszú legyen';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (isRegisterMode) ...[
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Jelszó megerősítése',
                      hintText: 'Add meg újra a jelszavad',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Kérjük, erősítsd meg a jelszavad';
                      }
                      if (value != _passwordController.text) {
                        return 'A jelszavak nem egyeznek meg';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _accessCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Hozzáférési kód',
                      hintText: 'Add meg a hozzáférési kódot',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.password),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Kérjük, add meg a hozzáférési kódot';
                      }
                      if (value.length < 4) {
                        return 'A hozzáférési kód legalább 4 karakter hosszú legyen';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
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
                    onPressed: _isLoading ? null : _submitForm,
                    child:
                        _isLoading
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
                            : Text(
                              _selectedMode,
                              style: const TextStyle(fontSize: 16),
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
