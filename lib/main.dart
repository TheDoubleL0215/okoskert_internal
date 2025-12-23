import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
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
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 16,
                        children: [
                          Text(
                            'A munkatér létrehozója hamarosan elfogadja a kérelmed!',
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                            },
                            child: const Text('Kijelentkezés'),
                          ),
                        ],
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
