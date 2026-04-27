import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth.dart';

// 1. The Entry Point 
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Load the environment variables
  await dotenv.load(fileName: ".env");

  // 3. Initialize Supabase 
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!, 
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const SmartHealthApp());
}

// 5. The Root Widget (App Configuration)
class SmartHealthApp extends StatelessWidget {
  const SmartHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartHealth',
      theme: ThemeData(
      // 1. Tell Flutter you explicitly want to use Material 3 (Good practice)
      useMaterial3: true, 
      
      // 2. Use colorScheme instead of primarySwatch
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
      ),
    ),
    home: const AuthScreen(),
    );
  }
}