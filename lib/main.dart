import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/app/home_page.dart';
import 'package:okoskert_internal/data/services/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:okoskert_internal/features/auth/ui/LoginScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

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
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = snapshot.data;
          if (user == null) {
            return const LoginScreen();
          }
          return const HomePage();
        },
      ),
    );
  }
}
