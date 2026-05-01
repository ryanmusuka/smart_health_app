import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart'; 
import 'package:google_fonts/google_fonts.dart';
import "notifications.dart";
import "profile.dart";
import "history.dart";
import "submit.dart";

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // --- STATE VARIABLES ---
  bool _isLoading = true;
  int _currentIndex = 0;

  // User Data
  String _firstName = '';
  String _membershipNumber = 'Pending...';
  
  // Claims Data
  List<dynamic> _recentClaims = [];
  int _pendingCount = 0;
  
  // Notification State
  bool _hasUnreadNotifications = false; // <-- ADDED: Track unread status

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

      // 4. Check for unread notifications <-- ADDED
      final unreadNotifications = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false)
          .limit(1); // We only need to check if at least one exists

      if (mounted) {
        setState(() {
          _firstName = profile['first_name'] ?? 'User';
          _membershipNumber = profile['membership_number'] ?? 'Not Assigned';
          _recentClaims = claims;
          _pendingCount = pendingClaims.length;
          _hasUnreadNotifications = unreadNotifications.isNotEmpty; // Set status
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

  // Update this to await the return and refresh the notification status
  Future<void> _navigateToNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
    // Re-fetch data when returning to clear the badge if they read them
    _fetchDashboardData(); 
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    );
  }

 
  Future<void> _navigateToSubmitClaim() async {
    // 1. Await the result of the Submit Screen
    final bool? shouldRefresh = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SubmitClaimScreen()), 
    );

    // 2. If it returns true (a successful submission), refresh the data!
    if (shouldRefresh == true) {
      setState(() {
        _isLoading = true; 
      });
      await _fetchDashboardData(); // Refreshes Profile, Recent Claims, and Pending Count
    }
  }

  // --- BOTTOM SHEET (CLAIM DETAILS) ---
  void _showClaimDetails(Map<String, dynamic> claim) {
    final amount = double.tryParse(claim['amount'].toString()) ?? 0.0;
    final status = (claim['status'] ?? 'pending').toString().toLowerCase();
    
    double covered = 0.0;
    double shortfall = 0.0;
    String rejectionReason = '';

    if (status == 'approved') {
      covered = amount;
    } else if (status == 'rejected') {
      shortfall = amount;
      rejectionReason = "Exceeded annual limit.";
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4, 
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              Text(claim['provider_name'] ?? 'Unknown Provider', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(claim['treatment_description'] ?? 'Medical Service', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              
              // Breakdown Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200)
                ),
                child: Column(
                  children: [
                    _buildBreakdownRow('Total Billed', amount, isBold: true),
                    const Divider(height: 24),
                    _buildBreakdownRow('Covered by Aid', covered, color: Colors.green),
                    const SizedBox(height: 12),
                    _buildBreakdownRow('Patient Shortfall', shortfall, color: shortfall > 0 ? Colors.red : Colors.black87),
                  ],
                ),
              ),

              if (status == 'rejected') ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Rejection Reason', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(rejectionReason, style: TextStyle(color: Colors.red.shade900, fontSize: 14)),
                          ],
                        ),
                      )
                    ],
                  ),
                )
              ],
              const SizedBox(height: 40),
            ],
          ),
        );
      }
    );
  }

  Widget _buildBreakdownRow(String label, double amount, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 15, color: Colors.grey.shade700, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(
          NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount),
          style: TextStyle(fontSize: 16, color: color ?? Colors.black87, fontWeight: isBold ? FontWeight.bold : FontWeight.w600),
        ),
      ],
    );
  }

  // --- WIDGET BUILDERS ---

  // <-- ADDED: SKELETON LOADER FOR DASHBOARD -->
  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fake Greeting
            Container(
              width: 200,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 20),

            // Fake Membership Card
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 30),

            // Fake Recent Activity Title
            Container(
              width: 140,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 15),

            // 3 Fake Recent Claim Cards
            ...List.generate(3, (index) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                )),
          ],
        ),
      ),
    );
  }

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
                    onTap: () => _showClaimDetails(claim),
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
  title: Hero(
    tag: 'smarthealth_logo', 
    child: Material(
      type: MaterialType.transparency,
      child: Text(
        'SmartHealth',
        style: GoogleFonts.outfit(
          color: Colors.blueAccent, 
          fontWeight: FontWeight.w900, 
          fontSize: 24, // Shrinks down gracefully to fit the app bar
          letterSpacing: -0.5,
          height: 1.0, 
        ),
      ),
    ),
  ),
        
        actions: [
          // THE NEW NOTIFICATION BADGE STACK
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.black, size: 28),
                onPressed: _navigateToNotifications,
              ),
              if (_hasUnreadNotifications)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
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
      body: _currentIndex == 0
          ? (_isLoading 
              ? _buildSkeletonLoader() // <-- CHANGED: Used Shimmer instead of CircularProgressIndicator
              : _buildHomeDashboard())
          : const HistoryScreen(), 

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
              Expanded(
                child: InkWell( 
                  onTap: () => setState(() => _currentIndex = 0), 
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.home_filled, 
                        color: _currentIndex == 0 ? Colors.blueAccent : Colors.grey, 
                      ),
                    ],
                  ),
                ),
              ),
              
              const Spacer(), 
              
              // Right side: History Tab
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _currentIndex = 1), 
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history, 
                        color: _currentIndex == 1 ? Colors.blueAccent : Colors.grey, 
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