import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:homespot/firebase_options.dart';
import 'package:homespot/screens/sign_in_screen.dart';
import 'package:homespot/screens/home_screen.dart'; // GANTI KE HomeScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fasum',
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

// === Wrapper untuk menentukan halaman awal berdasarkan status login ===
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Tampilkan loading saat proses auth
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Jika sudah login → HomeScreen
        if (snapshot.hasData) {
          return const HomeScreen();
        }

        // Jika belum login → LoginScreen
        return const SignInScreen();
      },
    );
  }
}
