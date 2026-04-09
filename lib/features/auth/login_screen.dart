import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:okoskert_internal/core/utils/login_error_messages.dart';
import 'package:okoskert_internal/features/auth/create_new_workspace_screen.dart';

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
    _nameController.dispose();
    super.dispose();
  }

  static const String _invitationUrl =
      'https://createinvitation-pyj4oehjla-uc.a.run.app';

  Future<bool> _validateInvitationByEmail(String email) async {
    final response = await http.post(
      Uri.parse(_invitationUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'action': 'validate'}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Szerver hiba: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['exists'] == true;
  }

  Future<bool> _verifyAccessCode(String code) async {
    final response = await http.post(
      Uri.parse(_invitationUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'verifyCode', 'code': code}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Szerver hiba: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['exists'] == true;
  }

  Future<bool> _showAccessCodeDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) =>
              _AccessCodeDialog(onSubmit: _joinWorkspaceWithAccessCode),
    );
    return result == true;
  }

  Future<String?> _joinWorkspaceWithAccessCode(String accessCode) async {
    final isValidCode = await _verifyAccessCode(accessCode);
    if (!isValidCode) {
      return 'A megadott hozzáférési kód nem található';
    }

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

    // A user létrehozása után már hitelesített, így olvasható a workspace.
    final workspaceQuery =
        await FirebaseFirestore.instance
            .collection('workspaces')
            .where('teamId', isEqualTo: accessCode)
            .limit(1)
            .get();
    if (workspaceQuery.docs.isNotEmpty) {
      final workspaceDoc = workspaceQuery.docs.first;
      await workspaceDoc.reference.collection('joinRequests').add({
        'userId': userCredential.user!.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    }

    if (!mounted) return null;
    setState(() {
      _successMessage = 'Csatlakozási kérés sikeresen elküldve!';
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
    return null;
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
        final email = _emailController.text.trim();
        final exists = await _validateInvitationByEmail(email);
        if (exists) {
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => CreateNewWorkspaceScreen(
                    signupName: _nameController.text.trim(),
                    signupEmail: email,
                    signupPassword: _passwordController.text,
                  ),
            ),
          );
          if (!mounted) return;
          setState(() {
            _nameController.clear();
            _emailController.clear();
            _passwordController.clear();
            _confirmPasswordController.clear();
          });
          return;
        }

        final joined = await _showAccessCodeDialog();
        if (!joined) {
          return;
        }
        return;
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

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Jelszó visszaállítása'),
            content: TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Add meg az email címed',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Mégse'),
              ),
              FilledButton(
                onPressed: () async {
                  final email = resetEmailController.text.trim();

                  if (email.isEmpty || !email.contains('@')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Adj meg egy érvényes email címet'),
                      ),
                    );
                    return;
                  }

                  try {
                    await FirebaseAuth.instance.sendPasswordResetEmail(
                      email: email,
                    );
                    if (!mounted) return;
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Jelszó-visszaállító email elküldve: $email',
                        ),
                      ),
                    );
                  } on FirebaseAuthException catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(getLoginErrorMessage(e.code))),
                    );
                  } catch (_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Hiba történt az email küldése közben. Próbáld újra.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Küldés'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRegisterMode = _selectedMode == 'Regisztráció';

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/logo.svg',
                  width: 200,
                  height: 200,
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      padding: WidgetStatePropertyAll(
                        EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      ),
                    ),
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
                  autocorrect: false,
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
                if (!isRegisterMode) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: const Text('Elfelejtettem a jelszavamat'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
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

class _AccessCodeDialog extends StatefulWidget {
  final Future<String?> Function(String accessCode) onSubmit;

  const _AccessCodeDialog({required this.onSubmit});

  @override
  State<_AccessCodeDialog> createState() => _AccessCodeDialogState();
}

class _AccessCodeDialogState extends State<_AccessCodeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() == true) {
      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });
      try {
        final error = await widget.onSubmit(_controller.text.trim());
        if (!mounted) return;
        if (error == null) {
          Navigator.pop(context, true);
          return;
        }
        setState(() {
          _errorMessage = error;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Csatlakozás közben hiba történt. Próbáld újra. $e';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hozzáférési kód megadása'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "A munkatérhez való csatlakozáshoz add meg a 6 karakter hosszúságú csapatazonosító kódot",
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Hozzáférési kód',
                hintText: 'pl.: ABC123',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Kérjük, add meg a hozzáférési kódot';
                }
                if (value.trim().length != 6) {
                  return 'A kód 6 karakter hosszú kell legyen';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
          child: const Text('Mégse'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child:
              _isSubmitting
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Folytatás'),
        ),
      ],
    );
  }
}
