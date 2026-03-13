import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:okoskert_internal/app/home_screen.dart';
import 'package:okoskert_internal/app/app_theme.dart';
import 'package:okoskert_internal/app/theme_provider.dart';
import 'package:okoskert_internal/app/workspace_provider.dart';
import 'package:okoskert_internal/data/services/employee_name_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:okoskert_internal/features/auth/login_screen.dart';
import 'package:okoskert_internal/features/auth/create_new_workspace_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('hu_HU', null);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => WorkspaceProvider()),
      ],
      child: MainApp(),
    ),
  );
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
    final themeProvider = context.watch<ThemeProvider>();
    return ToastificationWrapper(
      child: MaterialApp(
        locale: const Locale('hu', 'HU'),
        supportedLocales: const [Locale('hu', 'HU'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        themeMode: themeProvider.themeMode,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            ),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
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
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<WorkspaceProvider>().clearWorkspaceRef();
                EmployeeNameService.clearCache();
              });
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
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
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
                                        'A munkatér létrehozója hamarosan elfogadja a kérelmed és hozzádrendel egy szerepkört.',
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

                // Egyszer betöltjük a sessiont (prefs + workspace ref), aztán megjelenítjük a főoldalt
                return _AuthenticatedLoader(
                  teamId: teamId,
                  roleNumber: roleNumber,
                  saveUserPreferences: _saveUserPreferences,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Bejelentkezés után egyszer lefuttatja a prefs mentését és a workspace ref betöltését,
/// majd megjeleníti a HomePage-t. Így a workspaceRef minden widget számára már elérhető.
class _AuthenticatedLoader extends StatefulWidget {
  final dynamic teamId;
  final dynamic roleNumber;
  final Future<void> Function(dynamic teamId, dynamic roleNumber)
  saveUserPreferences;

  const _AuthenticatedLoader({
    required this.teamId,
    required this.roleNumber,
    required this.saveUserPreferences,
  });

  @override
  State<_AuthenticatedLoader> createState() => _AuthenticatedLoaderState();
}

class _AuthenticatedLoaderState extends State<_AuthenticatedLoader> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await widget.saveUserPreferences(widget.teamId, widget.roleNumber);
    if (!mounted) return;
    await context.read<WorkspaceProvider>().loadWorkspaceRef();
    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const HomePage();
  }
}
