import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth.dart';

// 1. Create the global notifier (defaults to light mode)
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// 2. The Entry Point 
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Load the environment variables
  await dotenv.load(fileName: ".env");

  // 4. Initialize Supabase 
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
    // 6. Listen to the themeNotifier
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, ThemeMode currentMode, child) {
        return MaterialApp(
          title: 'SmartHealth',
          debugShowCheckedModeBanner: false,
          
          // 7. Bind the active mode to the notifier's value
          themeMode: currentMode, 
          
          // --- LIGHT THEME ---
          theme: ThemeData(
            useMaterial3: true, 
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blueAccent,
              brightness: Brightness.light,
              secondary: Colors.blueGrey, 
            ),
            scaffoldBackgroundColor: Colors.grey[50],
          ),
          
          // --- DARK THEME ---
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blueAccent,
              brightness: Brightness.dark,
              secondary: Colors.blueGrey, 
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
          ),
          
          home: const AuthScreen(),
        );
      },
    );
  }
}