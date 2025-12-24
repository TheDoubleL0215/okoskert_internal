import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:okoskert_internal/app/home_page.dart';
import 'package:okoskert_internal/data/services/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:okoskert_internal/features/auth/LoginScreen.dart';
import 'package:okoskert_internal/features/auth/create_new_workspace_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('hu_HU', null);
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  Future<void> _saveUserPreferences(dynamic teamId, dynamic roleNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (teamId != null && teamId != '') {
        await prefs.setString('teamId', teamId.toString());
      }
      if (roleNumber != null) {
        await prefs.setInt(
          'role',
          roleNumber is int
              ? roleNumber
              : int.tryParse(roleNumber.toString()) ?? 0,
        );
      }
    } catch (e) {
      debugPrint('Hiba a SharedPreferences mentésekor: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightGreen,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = authSnapshot.data;
          if (user == null) {
            return const LoginScreen();
          }

          // Ellenőrizzük a felhasználó adatait a Firestore-ból (uid alapján)
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              // Ha nincs dokumentum, navigáljunk a LoginScreen-re
              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                return const LoginScreen();
              }

              final userData = userSnapshot.data!.data();
              if (userData == null) {
                return const LoginScreen();
              }

              final teamId = userData['teamId'];
              final roleNumber = userData['role'];

              // Ha nincs érvényes teamId, navigáljunk a CreateNewWorkspaceScreen-re
              if ((teamId == null || teamId == '') && roleNumber == 1) {
                return const CreateNewWorkspaceScreen();
              }

              if (roleNumber == null || roleNumber == '') {
                return Scaffold(
                  body: Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Card(
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.pending_actions,
                                      size: 64,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Várakozás a jóváhagyásra',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'A munkatér létrehozója hamarosan elfogadja a kérelmed és hozzárendel egy szerepkört.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.copyWith(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 32),
                                    const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CupertinoActivityIndicator(
                                        radius: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    TextButton.icon(
                                      onPressed: () async {
                                        await FirebaseAuth.instance.signOut();
                                      },
                                      icon: const Icon(Icons.logout),
                                      label: const Text('Kijelentkezés'),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(
                                          double.infinity,
                                          48,
                                        ),
                                      ),
                                    ),
                                  ],
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

              // Mentjük a teamId-t és role-t SharedPreferences-be
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _saveUserPreferences(teamId, roleNumber);
              });

              return const HomePage();
            },
          );
        },
      ),
    );
  }
}
