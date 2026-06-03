import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'auth.dart'; 

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
      
      // Fetch both tables independently but simultaneously using the user_id
      final responses = await Future.wait([
        // 1. Get the Profile Identity
        supabase.from('profiles').select().eq('id', userId).single(),
        
        // 2. Get the Medical Info. 
        // We use maybeSingle() in case the row doesn't exist yet for a new user.
        supabase.from('medical_information').select().eq('user_id', userId).maybeSingle(),
      ]);

      if (mounted) {
        setState(() {
          _profileData = responses[0];
          // If medical data exists, assign it. Otherwise, use an empty map to prevent null errors.
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
        MaterialPageRoute(builder: (context) => const AuthScreen()), // Ensure AuthScreen matches your class
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String? value, {IconData? icon, Color? iconColor}) {
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
      title: Text(title, style: const TextStyle(color: Colors.black54, fontSize: 14)),
      subtitle: Text(
        (value == null || value.isEmpty) ? 'Not provided' : value, 
        style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }

  // --- CUSTOM PROFILE SKELETON LOADER ---
  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40, top: 20),
        child: Column(
          children: [
            // Fake Avatar
            Container(width: 100, height: 100, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(height: 16),
            // Fake Name
            Container(width: 180, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            // Fake Membership Number
            Container(width: 140, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 32),
            
            // Fake Cards Sections
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? _buildSkeletonLoader() // Triggers the Shimmer while fetching
          : _profileData == null
              ? const Center(child: Text('Failed to load profile data.'))
              : _buildProfileContent(),
    );
  }

  // Separated the content into its own method to keep the build method clean
  Widget _buildProfileContent() {
    final firstName = _profileData!['first_name'] as String?;
    final lastName = _profileData!['last_name'] as String?;
    final fullName = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    final membershipNum = _profileData!['membership_number'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 1. THE HEADER (IDENTITY) ---
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
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  membershipNum ?? 'No Membership Number',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // --- 2. MEDICAL INFORMATION ---
          _buildSectionHeader('Medical Info & Risks'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: [
                _buildInfoTile('Blood Type', _medicalData['blood_type'], icon: Icons.water_drop, iconColor: Colors.redAccent),
                const Divider(height: 1, indent: 56),
                _buildInfoTile('Allergies', _medicalData['allergies'], icon: Icons.warning_amber_rounded, iconColor: Colors.red),
                const Divider(height: 1, indent: 56),
                _buildInfoTile('Chronic Conditions', _medicalData['chronic_conditions'], icon: Icons.medical_services_outlined, iconColor: Colors.orange),
                const Divider(height: 1, indent: 56),
                _buildInfoTile('Current Medications', _medicalData['current_medications'], icon: Icons.medication, iconColor: Colors.teal),
              ],
            ),
          ),

          // --- 3. EMERGENCY CONTACT & SETTINGS ---
          _buildSectionHeader('Emergency Contact'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: [
                _buildInfoTile('Name', _profileData!['emergency_contact_name'], icon: Icons.person_outline, iconColor: Colors.blueGrey),
                const Divider(height: 1, indent: 56),
                _buildInfoTile('Phone Number', _profileData!['emergency_contact_phone'], icon: Icons.phone, iconColor: Colors.green),
              ],
            ),
          ),

          _buildSectionHeader('Preferences'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.w500)),
                  secondary: const Icon(Icons.notifications_active_outlined, color: Colors.blueAccent),
                  activeColor: Colors.blueAccent,
                  value: _notificationsEnabled,
                  onChanged: (bool value) => setState(() => _notificationsEnabled = value),
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  title: const Text('FaceID / Biometric Login', style: TextStyle(fontWeight: FontWeight.w500)),
                  secondary: const Icon(Icons.fingerprint, color: Colors.blueAccent),
                  activeColor: Colors.blueAccent,
                  value: _biometricsEnabled,
                  onChanged: (bool value) => setState(() => _biometricsEnabled = value),
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