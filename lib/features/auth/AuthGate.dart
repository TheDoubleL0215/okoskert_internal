import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:okoskert_internal/features/auth/LoginScreen.dart';
import 'package:okoskert_internal/features/home_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While waiting for Firebase to initialize
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If the user is logged in
        if (snapshot.hasData) {
          return const HomePage();
        }

        // If the user is not logged in
        return const LoginScreen();
      },
    );
  }
}
