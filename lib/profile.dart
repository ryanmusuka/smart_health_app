import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'auth.dart'; 
import 'main.dart'; // Brings in the themeNotifier

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  Map<String, dynamic> _medicalData = {};

  // Local state for UI toggles
  bool _notificationsEnabled = true;
  bool _biometricsEnabled = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      
      final responses = await Future.wait([
        supabase.from('profiles').select().eq('id', userId).single(),
        supabase.from('medical_information').select().eq('user_id', userId).maybeSingle(),
      ]);

      if (mounted) {
        setState(() {
          _profileData = responses[0];
          _medicalData = responses[1] ?? {}; 
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()), 
        (route) => false,
      );
    }
  }

  String _getInitials(String? first, String? last) {
    String initials = '';
    if (first != null && first.isNotEmpty) initials += first[0];
    if (last != null && last.isNotEmpty) initials += last[0];
    return initials.toUpperCase();
  }

  // --- THEME AWARE HELPERS ---
  // We pass 'isDark' into these so they know what colors to use
  
  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String? value, bool isDark, {IconData? icon, Color? iconColor}) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: icon != null 
          ? Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: (iconColor ?? Colors.blue).withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor ?? Colors.blue, size: 20),
            )
          : null,
      title: Text(title, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14)),
      subtitle: Text(
        (value == null || value.isEmpty) ? 'Not provided' : value, 
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40, top: 20),
        child: Column(
          children: [
            Container(width: 100, height: 100, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(height: 16),
            Container(width: 180, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            Container(width: 140, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 32),
            for (int i = 0; i < 3; i++) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 24, bottom: 8),
                  child: Container(width: 120, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                height: 140,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              ),
              const SizedBox(height: 16),
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Check if the app is currently in dark mode
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // 2. Make the background color respond to the theme
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFC), 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // 3. Make the App Bar text and icon respond to the theme
        title: Text('Profile', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)), 
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: _isLoading
          ? _buildSkeletonLoader() 
          : _profileData == null
              ? const Center(child: Text('Failed to load profile data.'))
              : _buildProfileContent(isDark), // Pass the theme info down
    );
  }

  Widget _buildProfileContent(bool isDark) {
    final firstName = _profileData!['first_name'] as String?;
    final lastName = _profileData!['last_name'] as String?;
    final fullName = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    final membershipNum = _profileData!['membership_number'] as String?;

    // 4. Define the container colors based on the theme
    final containerColor = isDark ? Colors.grey[900] : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey.shade200;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- THE HEADER (IDENTITY) ---
          Center(
            child: Column(
              children: [
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                  child: Text(
                    _getInitials(firstName, lastName),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  fullName.isEmpty ? 'Unknown User' : fullName,
                  // Respond to theme
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  membershipNum ?? 'No Membership Number',
                  style: TextStyle(fontSize: 16, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // --- MEDICAL INFORMATION ---
          _buildSectionHeader('Medical Info & Risks', isDark),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: containerColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              children: [
                _buildInfoTile('Blood Type', _medicalData['blood_type'], isDark, icon: Icons.water_drop, iconColor: Colors.redAccent),
                Divider(height: 1, indent: 56, color: borderColor),
                _buildInfoTile('Allergies', _medicalData['allergies'], isDark, icon: Icons.warning_amber_rounded, iconColor: Colors.red),
                Divider(height: 1, indent: 56, color: borderColor),
                _buildInfoTile('Chronic Conditions', _medicalData['chronic_conditions'], isDark, icon: Icons.medical_services_outlined, iconColor: Colors.orange),
                Divider(height: 1, indent: 56, color: borderColor),
                _buildInfoTile('Current Medications', _medicalData['current_medications'], isDark, icon: Icons.medication, iconColor: Colors.teal),
              ],
            ),
          ),

          // --- EMERGENCY CONTACT ---
          _buildSectionHeader('Emergency Contact', isDark),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: containerColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              children: [
                _buildInfoTile('Name', _profileData!['emergency_contact_name'], isDark, icon: Icons.person_outline, iconColor: Colors.blueGrey),
                Divider(height: 1, indent: 56, color: borderColor),
                _buildInfoTile('Phone Number', _profileData!['emergency_contact_phone'], isDark, icon: Icons.phone, iconColor: Colors.green),
              ],
            ),
          ),

          // --- PREFERENCES ---
          _buildSectionHeader('Preferences', isDark),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: containerColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black)),
                  secondary: const Icon(Icons.notifications_active_outlined, color: Colors.blueAccent),
                  activeColor: Colors.blueAccent,
                  value: _notificationsEnabled,
                  onChanged: (bool value) => setState(() => _notificationsEnabled = value),
                ),
                Divider(height: 1, indent: 56, color: borderColor),
                SwitchListTile(
                  title: Text('FaceID / Biometric Login', style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black)),
                  secondary: const Icon(Icons.fingerprint, color: Colors.blueAccent),
                  activeColor: Colors.blueAccent,
                  value: _biometricsEnabled,
                  onChanged: (bool value) => setState(() => _biometricsEnabled = value),
                ),
                Divider(height: 1, indent: 56, color: borderColor),
                
                // 5. THE FIX: Wrap the Theme Switch in a ValueListenableBuilder
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (context, currentMode, child) {
                    final isCurrentlyDark = currentMode == ThemeMode.dark;
                    return SwitchListTile(
                      title: Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black)),
                      secondary: Icon(
                        isCurrentlyDark ? Icons.dark_mode : Icons.light_mode,
                        color: Colors.blueAccent,
                      ),
                      activeColor: Colors.blueAccent,
                      value: isCurrentlyDark, 
                      onChanged: (bool newValue) {
                        // This updates the global variable, triggering the whole app to rebuild!
                        themeNotifier.value = newValue ? ThemeMode.dark : ThemeMode.light;
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // --- THE FOOTER (LOGOUT) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent, 
                  foregroundColor: Colors.white,     
                  elevation: 0,
                  shape: const StadiumBorder(),      
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}