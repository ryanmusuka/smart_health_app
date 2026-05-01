import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import "dashboard.dart";
import 'package:google_fonts/google_fonts.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // 1. Ephemeral State
  bool _isLogin = true;
  bool _isLoading = false; 

  // 2. Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    super.dispose();
  }

  // --- FORGOT PASSWORD LOGIC ---
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    
    // Check if they actually typed an email first
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your valid email address in the box above first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await supabase.auth.resetPasswordForEmail(email);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Check your inbox! 📧'),
            content: const Text('A link has been sent to your email with further instructions on how to reset your password.'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Got it!', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A link has been sent to your email with further instructions on how to reset your password.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitAuth() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) return;

    setState(() {
      _isLoading = true; // Start loading animation
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (_isLogin) {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        
        if (mounted) {  
          // --- THE NEW ANIMATED TRANSITION ---
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const DashboardScreen(),
              transitionDuration: const Duration(milliseconds: 600), // Smooth, deliberate timing
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                // 1. The Slide Animation (Starts slightly lower and moves up to center)
                const beginOffset = Offset(0.0, 0.05); 
                const endOffset = Offset.zero;
                const curve = Curves.easeOutCubic; // Starts fast, settles gently

                var slideTween = Tween(begin: beginOffset, end: endOffset).chain(CurveTween(curve: curve));
                
                // 2. The Fade Animation (Starts invisible, fades to full opacity)
                var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

                return FadeTransition(
                  opacity: animation.drive(fadeTween),
                  child: SlideTransition(
                    position: animation.drive(slideTween),
                    child: child,
                  ),
                );
              },
            ),
          );
        }
      } else {
        // ACTUAL SUPABASE REGISTRATION
        final name = _nameController.text.trim();
        final surname = _surnameController.text.trim();
        
        await supabase.auth.signUp(
          email: email,
          password: password,
          data: {
            'first_name': name,
            'last_name': surname,
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration Successful! Please check your email.')),
          );
          // automatically switch to login screen after successful registration
          setState(() {
            _isLogin = true;
          });
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      // Catch any other unexpected errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unexpected error occurred.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Stop loading animation
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueAccent, // Light background color for better contrast
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4, // Adds a subtle drop shadow 
            color: const Color(0xFFF9FAF6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- THE HERO LOGO ---
                    Center(
                      child: Hero(
                        tag: 'smarthealth_logo', // This tag MUST match the dashboard
                        flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
                          // This ensures smooth text resizing during the animation
                          return DefaultTextStyle(
                            style: DefaultTextStyle.of(toHeroContext).style,
                            child: toHeroContext.widget,
                          );
                        },
                        child: Material(
                          type: MaterialType.transparency, 
                          child: Text(
                            'SmartHealth',
                            style: GoogleFonts.outfit( 
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.w900, 
                              fontSize: 42,
                              letterSpacing: -1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    Text(
                      _isLogin ? 'WELCOME BACK!' : 'CREATE ACCOUNT',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    if (!_isLogin) ...[
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (val) => val!.isEmpty ? 'Enter your name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _surnameController,
                        decoration: const InputDecoration(
                          labelText: 'Surname',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (val) => val!.isEmpty ? 'Enter your surname' : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) => !val!.contains('@') ? 'Invalid email' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      validator: (val) => val!.length < 6 ? 'Password must be at least 6 characters' : null,
                    ),
                    
                    // FORGOT PASSWORD BUTTON
                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _resetPassword,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Forgot Password?', style: TextStyle(color: Colors.blueAccent)),
                        ),
                      ),

                    const SizedBox(height: 16),

                    if (!_isLogin) ...[
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        validator: (val) => val != _passwordController.text ? 'Passwords do not match' : null,
                      ),
                      const SizedBox(height: 24),
                    ],

                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _submitAuth,
                            child: Text(
                              _isLogin ? 'Login' : 'Register',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                    
                    const SizedBox(height: 16),

                   TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin; 
                        });
                      },
                      child: Text(
                        _isLogin 
                            ? 'No account? Click to register.' 
                            : 'Already registered? Login here',
                        style: const TextStyle(color: Colors.blueAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}