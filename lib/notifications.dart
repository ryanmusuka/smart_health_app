import 'dart:async';
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

  late final StreamSubscription _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _setupRealtimeNotifications(); 
  }

void _setupRealtimeNotifications() {
    final userId = supabase.auth.currentUser!.id;

    // We use .stream() instead of .select() to open a live WebSocket connection
    _notificationSubscription = supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .listen((List<Map<String, dynamic>> data) {
      
      // This block fires instantly every time a row is INSERTED, UPDATED, or DELETED in Supabase!
      if (mounted) {
        setState(() {
          _notifications = data;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      print('Realtime Error: $error');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _notificationSubscription.cancel(); // Close the connection when leaving the screen
    super.dispose();
  }

  // --- 1. YOUTUBE STYLE DATE FORMATTING ---
  String _getGroupHeader(Map<String, dynamic> note) {
    if (note['is_read'] == false) {
      return 'Important';
    }

    // Parse the Supabase timestamp
    DateTime noteDate = DateTime.parse(note['created_at']).toLocal();
    DateTime now = DateTime.now();
    
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = today.subtract(const Duration(days: 1));
    DateTime noteDay = DateTime(noteDate.year, noteDate.month, noteDate.day);

    if (noteDay == today) {
      return 'Today';
    } else if (noteDay == yesterday) {
      return 'Yesterday';
    } else {
      // Formats as "12 April"
      List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${noteDate.day} ${months[noteDate.month - 1]}';
    }
  }

  // --- 2. PAYPAL STYLE ICONS (Flat & Black) ---
  Widget _buildPayPalIcon(String title) {
    IconData iconData = Icons.notifications_none_outlined;
    final lowerTitle = title.toLowerCase();

    if (lowerTitle.contains('approved')) {
      iconData = Icons.check_circle_outline;
    } else if (lowerTitle.contains('rejected')) {
      iconData = Icons.highlight_off;
    } else if (lowerTitle.contains('processing') || lowerTitle.contains('pending')) {
      iconData = Icons.hourglass_empty;
    } else {
      iconData = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[200], // PayPal's signature light grey icon background
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: Colors.black87, size: 24),
    );
  }

  // --- 3. THE SKELETON LOADER ---
  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: 8, // Show 8 fake items while loading
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fake Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              // Fake Text Lines
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Container(width: 200, height: 16, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Container(width: double.infinity, height: 14, color: Colors.grey[200]),
                    const SizedBox(height: 4),
                    Container(width: 150, height: 14, color: Colors.grey[200]),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Group the notifications based on our logic
    Map<String, List<dynamic>> groupedNotes = {};
    for (var note in _notifications) {
      String group = _getGroupHeader(note);
      if (!groupedNotes.containsKey(group)) {
        groupedNotes[group] = [];
      }
      groupedNotes[group]!.add(note);
    }

    return Scaffold(
      backgroundColor: Colors.white, // YouTube/PayPal use pure white backgrounds mostly
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? _buildSkeletonLoader()
          : _notifications.isEmpty
              ? const Center(child: Text('You have no notifications.'))
              : ListView(
                  children: groupedNotes.entries.map((entry) {
                    String header = entry.key;
                    List<dynamic> items = entry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The YouTube-style Subheading
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
                          child: Text(
                            header,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        
                        // The List of Notifications for this group
                        ...items.map((note) {
                          final isRead = note['is_read'] as bool;
                          return Container(
                            // Optional: Give unread items a very subtle background tint like YouTube does
                            color: isRead ? Colors.transparent : Colors.blue.withOpacity(0.05),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: _buildPayPalIcon(note['title']),
                              title: Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Text(
                                  note['title'],
                                  style: TextStyle(
                                    fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              subtitle: Text(
                                note['message'],
                                style: const TextStyle(color: Colors.black87, height: 1.3),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.more_vert, color: Colors.grey),
                                onPressed: () {
                                  // Can add delete/mark-as-read options here later
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    );
                  }).toList(),
                ),
    );
  }
}