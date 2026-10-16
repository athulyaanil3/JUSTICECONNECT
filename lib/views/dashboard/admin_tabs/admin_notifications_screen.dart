import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({Key? key}) : super(key: key);

  @override
  _AdminNotificationsScreenState createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAdminNotifications();
  }

  Future<void> _fetchAdminNotifications() async {
    setState(() => _isLoading = true);
    final List<Map<String, dynamic>> combined = [];

    try {
      // 1. Fetch complaints and general alerts from app_notifications
      try {
        final notifs = await _supabase
            .from('app_notifications')
            .select()
            .eq('target_user', 'Admin')
            .order('created_at', ascending: false);

        for (var n in notifs) {
          combined.add({
            'type': 'complaint',
            'id': n['id']?.toString() ?? '',
            'title': n['title'] ?? 'Notification',
            'message': n['message'] ?? '',
            'is_read': n['is_read'] ?? false,
            'created_at': n['created_at'],
            'action_payload': n['action_payload'],
          });
        }
      } catch (e) {
        debugPrint('Error fetching app_notifications for admin: $e');
      }

      // 2. Fetch pending verification requests for Lawyers
      try {
        final pendingProfiles = await _supabase
            .from('profiles')
            .select()
            .eq('is_verified', false)
            .eq('role', 'Lawyer');

        for (var p in pendingProfiles) {
          final role = p['role'] ?? 'User';
          final username = p['username'] ?? 'Unknown User';
          combined.add({
            'type': 'verification',
            'id': p['id']?.toString() ?? '',
            'title': 'New $role Registration',
            'message': '$username has registered as $role and is awaiting document verification.',
            'is_read': false,
            'created_at': p['created_at'],
            'profile_data': p,
          });
        }
      } catch (e) {
        debugPrint('Error fetching pending profile requests: $e');
      }

      // Sort by newest first
      combined.sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
        final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _notifications = combined;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching admin notifications: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showComplaintDetails(Map<String, dynamic> notif) {
    Map<String, dynamic> payload = {};
    if (notif['action_payload'] != null && notif['action_payload'].toString().isNotEmpty) {
      try {
        payload = jsonDecode(notif['action_payload'].toString());
      } catch (_) {}
    }

    final title = payload['title'] ?? notif['title'] ?? 'Complaint';
    final desc = payload['description'] ?? notif['message'] ?? '';
    final category = payload['category'] ?? 'General';
    final priority = payload['priority'] ?? 'Medium';
    final userName = payload['user_name'] ?? 'User';
    final userEmail = payload['user_email'] ?? '';
    final userRole = payload['user_role'] ?? 'Citizen';
    final status = payload['status'] ?? 'Pending';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: priority == 'Urgent'
                          ? Colors.red.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      priority,
                      style: TextStyle(
                        color: priority == 'Urgent' ? Colors.red : Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Filed by: $userName ($userRole)', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              if (userEmail.isNotEmpty)
                Text('Email: $userEmail', style: GoogleFonts.inter(color: Colors.grey[700])),
              Text('Category: $category', style: GoogleFonts.inter(color: Colors.grey[700])),
              Text('Status: $status', style: GoogleFonts.inter(color: Colors.blue[800], fontWeight: FontWeight.bold)),
              const Divider(height: 24),
              Text('Description:', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(desc, style: GoogleFonts.inter(fontSize: 14)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Open Complaint Management'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D256C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context); // Go back to dashboard where complaints tab is available
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text(
          'Admin Notifications',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: const Color(0xFF0D256C)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D256C),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAdminNotifications,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No new notifications',
                        style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchAdminNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final item = _notifications[index];
                      final isComplaint = item['type'] == 'complaint';
                      final title = item['title'] ?? 'Notification';
                      final message = item['message'] ?? '';
                      final time = item['created_at'] != null
                          ? DateTime.tryParse(item['created_at'].toString())?.toLocal().toString().substring(0, 16) ?? 'Recently'
                          : 'Recently';

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isComplaint ? Colors.orange.withOpacity(0.5) : Colors.blue.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isComplaint ? Colors.orange.shade100 : Colors.blue.shade100,
                            child: Icon(
                              isComplaint ? Icons.report_problem : Icons.person_add,
                              color: isComplaint ? Colors.orange.shade800 : Colors.blue.shade800,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              if (isComplaint)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Text('Grievance', style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[800]),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                time,
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () {
                            if (isComplaint) {
                              _showComplaintDetails(item);
                            } else {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please check the Lawyer Management tab to review.')),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
