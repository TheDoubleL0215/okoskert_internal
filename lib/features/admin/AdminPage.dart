import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
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
