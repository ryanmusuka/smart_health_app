import 'package:flutter/material.dart';

// 1. The Entry Point
void main() {
  runApp(const SmartHealthApp());
}

// 2. The Root Widget (App Configuration)
class SmartHealthApp extends StatelessWidget {
  const SmartHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartHealth',
      theme: ThemeData(
        // Let's use a nice medical blue theme
        primarySwatch: Colors.blue, 
      ),
      // 3. The First Screen the user sees
      home: const LoginScreen(), 
    );
  }
}

// 4. Our First Screen (Placeholder for now)
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartHealth - Login'),
      ),
      body: const Center(
        child: Text(
          'Welcome to SmartHealth!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}