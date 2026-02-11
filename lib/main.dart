import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth/login_signup_page.dart'; // your login screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase only ONCE
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
      debugShowCheckedModeBanner: false,
      home: LoginSignupPage(), // ← LOAD YOUR LOGIN PAGE
    );
  }
}
