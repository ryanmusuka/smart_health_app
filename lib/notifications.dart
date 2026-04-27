import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _notifications = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- THE CATEGORIZATION LOGIC ---
  Widget _getIconForCategory(String title) {
    final lowerTitle = title.toLowerCase();
    
    if (lowerTitle.contains('approved')) {
      return const CircleAvatar(
        backgroundColor: Color(0xFFE8F5E9), // Light green
        child: Icon(Icons.check_circle, color: Colors.green),
      );
    } else if (lowerTitle.contains('rejected')) {
      return const CircleAvatar(
        backgroundColor: Color(0xFFFFEBEE), // Light red
        child: Icon(Icons.cancel, color: Colors.red),
      );
    } else if (lowerTitle.contains('processing') || lowerTitle.contains('pending')) {
      return const CircleAvatar(
        backgroundColor: Color(0xFFFFF3E0), // Light orange
        child: Icon(Icons.access_time_filled, color: Colors.orange),
      );
    } else {
      // Default / Welcome messages
      return const CircleAvatar(
        backgroundColor: Color(0xFFE3F2FD), // Light blue
        child: Icon(Icons.info, color: Colors.blueAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC), 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black), // Makes back button black
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.blueAccent, height: 1.0),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _notifications.isEmpty
              ? const Center(child: Text('You have no notifications.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final note = _notifications[index];
                    final isRead = note['is_read'] as bool;

                    return Card(
                      elevation: 0, // Flat design
                      color: isRead ? Colors.white : const Color(0xFFF0F4FA), // Slightly blue if unread
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: _getIconForCategory(note['title']),
                        title: Text(
                          note['title'],
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold, // Bolder if unread
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            note['message'],
                            style: const TextStyle(color: Colors.black54, height: 1.3),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}