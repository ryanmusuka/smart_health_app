import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import "notifications.dart";
import "profile.dart";
import "history.dart";

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // --- STATE VARIABLES ---
  // Removed _selectedIndex since Dashboard is now a single, standalone screen
  bool _isLoading = true;
  
  // User Data
  String _firstName = '';
  String _membershipNumber = 'Pending...';
  
  // Claims Data
  List<dynamic> _recentClaims = [];
  int _pendingCount = 0;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  // --- ASYNCHRONOUS DATA FETCHING ---
  Future<void> _fetchDashboardData() async {
    try {
      final userId = supabase.auth.currentUser!.id;

      // 1. Fetch Profile Info
      final profile = await supabase
          .from('profiles')
          .select('first_name, membership_number')
          .eq('id', userId)
          .single();

      // 2. Fetch Recent Claims 
      final claims = await supabase
          .from('claims')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(3);

      // 3. Count Pending Claims
      final pendingClaims = await supabase
          .from('claims')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'pending');

      if (mounted) {
        setState(() {
          _firstName = profile['first_name'] ?? 'User';
          _membershipNumber = profile['membership_number'] ?? 'Not Assigned';
          _recentClaims = claims;
          _pendingCount = pendingClaims.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- NAVIGATION HELPERS ---
  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    );
  }

  void _navigateToSubmitClaim() {
    // TODO: Add Navigator.push for the SubmitClaimScreen later
    print("Submit Claim clicked");
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHomeDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, $_firstName',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 20),

          // 2. Premium Membership Card (Using Core Colors)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black, 
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Medical Aid Number', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  _membershipNumber,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pending Claims', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _pendingCount.toString(),
                        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // 3. Recent Activity Section
          const Text('Recent Claims', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 15),
          
          if (_recentClaims.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('No recent claims found.')))
          else
            ListView.builder(
              shrinkWrap: true, 
              physics: const NeverScrollableScrollPhysics(), 
              itemCount: _recentClaims.length,
              itemBuilder: (context, index) {
                final claim = _recentClaims[index];
                final isApproved = claim['status'] == 'approved';
                return Card(
                  color: const Color(0xFFF9FAF6),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueAccent.withOpacity(0.1),
                      child: const Icon(Icons.local_hospital, color: Colors.blueAccent),
                    ),
                    title: Text(claim['provider_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(claim['claim_date'].toString().substring(0, 10)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('\$${claim['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          claim['status'].toString().toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isApproved ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      
      // --- THE APP BAR ---
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        
        centerTitle: false, 
        title: const Text(
          'SmartHealth',
          style: TextStyle(
            color: Colors.blueAccent, 
            fontWeight: FontWeight.bold, 
            fontSize: 24,
            height: 1.0, 
          ),
        ),
        
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.black, size: 28),
            onPressed: _navigateToNotifications,
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.black, size: 30),
            onPressed: _navigateToProfile,
          ),
          const SizedBox(width: 8), 
        ],

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.blueAccent,
            height: 3.0, 
          ),
        ),
      ),

      // --- THE BODY ---
      // Removed the ternary operator that toggled the history tab
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _buildHomeDashboard(),

      // --- SUBMIT CLAIM FAB (Center Docked) ---
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToSubmitClaim,
        backgroundColor: Colors.blueAccent,
        elevation: 4,
        shape: const CircleBorder(), 
        child: const Icon(Icons.add, size: 32, color: Colors.white),
      ),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // BOTTOM NAVIGATION BAR ---
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 2.0, 
        color: const Color(0xFFF9FAF6),
        elevation: 10,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              // Left side: Home Tab
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.home_filled, 
                      color: Colors.blueAccent, // Always blue because this is the Dashboard
                    ),
                   ],
                ),
              ),
              
              const Spacer(), 
              
              // Right side: History Tab
              Expanded(
                child: InkWell(
                  onTap: _navigateToHistory, // Now pushes to the new screen!
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history, 
                        color: Colors.grey, // Grey because it acts as a button leading to a new screen
                      ),
                       ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}