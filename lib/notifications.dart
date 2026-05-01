import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';

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

  // --- SORTING LOGIC ---
  void _sortNotifications() {
    _notifications.sort((a, b) {
      bool aIsRead = a['is_read'] ?? true;
      bool bIsRead = b['is_read'] ?? true;
      
      if (!aIsRead && bIsRead) return -1; // 'a' is unread, move it up
      if (aIsRead && !bIsRead) return 1;  // 'b' is unread, move it up

      // If both have the same read status, sort by Date (Newest first)
      DateTime dateA = DateTime.parse(a['created_at']);
      DateTime dateB = DateTime.parse(b['created_at']);
      return dateB.compareTo(dateA); 
    });
  }

void _setupRealtimeNotifications() {
    final userId = supabase.auth.currentUser!.id;
    
    _notificationSubscription = supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .listen((List<Map<String, dynamic>> data) {
      
      if (mounted) {
        setState(() {
          _notifications = data; 
          _sortNotifications();  
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
    _notificationSubscription.cancel(); 
    super.dispose();
  }

  // --- NOTIFICATION ACTIONS ---
  
Future<void> _toggleReadStatus(dynamic id, bool currentStatus) async {
    final bool newStatus = !currentStatus;

    // --- OPTIMISTIC UI UPDATE ---
    setState(() {
      final index = _notifications.indexWhere((note) => note['id'] == id);
      if (index != -1) {
        Map<String, dynamic> updatedNote = Map<String, dynamic>.from(_notifications[index]);
        
        updatedNote['is_read'] = newStatus;
        // Replace the old note with the updated one
        _notifications[index] = updatedNote;
        
       _sortNotifications(); 
      }
    });

    // --- DATABASE UPDATE ---
    try {
      await supabase
          .from('notifications')
          .update({'is_read': newStatus})
          .eq('id', id);
    } catch (e) {
      print('UPDATE ERROR: $e');
      
      // Revert if the database fails
      setState(() {
        final index = _notifications.indexWhere((note) => note['id'] == id);
        if (index != -1) {
          Map<String, dynamic> revertedNote = Map<String, dynamic>.from(_notifications[index]);
          revertedNote['is_read'] = currentStatus;
          _notifications[index] = revertedNote;
          _sortNotifications(); 
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status.')),
        );
      }
    }
  }

Future<void> _deleteNotification(dynamic id) async {
    // Store a backup of the notification in case we need to revert
    final int index = _notifications.indexWhere((note) => note['id'] == id);
    final dynamic deletedNote = index != -1 ? _notifications[index] : null;

    if (index == -1) return;
    // Instantly remove it from the screen
    setState(() {
      _notifications.removeAt(index);
    });

    // --- DATABASE DELETE ---
    try {
      await supabase
          .from('notifications')
          .delete()
          .eq('id', id);
    } catch (e) {
      print('DELETE ERROR: $e');
      
      // If the database fails, put the notification back on the screen!
      setState(() {
        if (deletedNote != null) {
          _notifications.insert(index, deletedNote);
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete notification.')),
        );
      }
    }
  }

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
      List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${noteDate.day} ${months[noteDate.month - 1]}';
    }
  }

  // --- 2. ICONS (Flat & Black) ---
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
        color: Colors.grey[200],
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: Colors.black87, size: 24),
    );
  }

  // --- 3. THE SKELETON LOADER ---
  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,     
      highlightColor: Colors.grey.shade100, 
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: 8, 
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
                  decoration: const BoxDecoration(
                    color: Colors.white, 
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
                       Container(
                        width: 200, 
                        height: 16, 
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity, 
                        height: 14, 
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 150, 
                        height: 14, 
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Group the notifications based on the logic
    Map<String, List<dynamic>> groupedNotes = {};
    for (var note in _notifications) {
      String group = _getGroupHeader(note);
      if (!groupedNotes.containsKey(group)) {
        groupedNotes[group] = [];
      }
      groupedNotes[group]!.add(note);
    }

    return Scaffold(
      backgroundColor: Colors.white, 
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
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.grey),
                                color: Colors.white, 
                                onSelected: (value) {
                                  if (value == 'toggle_read') {
                                    _toggleReadStatus(note['id'], isRead);
                                  } else if (value == 'delete') {
                                    _deleteNotification(note['id']);
                                  }
                                },
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                  
                                  // OPTION 1: Mark as Read / Unread
                                  PopupMenuItem<String>(
                                    value: 'toggle_read',
                                    child: Row(
                                      children: [
                                        Icon(
                                          isRead ? Icons.mark_email_unread_outlined : Icons.mark_email_read_outlined, 
                                          color: Colors.black87, 
                                          size: 20
                                        ),
                                        const SizedBox(width: 12),
                                        Text(isRead ? 'Mark as unread' : 'Mark as read'),
                                      ],
                                    ),
                                  ),
                                  
                                  // OPTION 2: Delete
                                  const PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                        SizedBox(width: 12),
                                        Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                      ],
                                    ),
                                  ),
                                ],
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