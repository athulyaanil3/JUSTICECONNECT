import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class AdvocateClerkNotificationsScreen extends StatefulWidget {
  const AdvocateClerkNotificationsScreen({Key? key}) : super(key: key);

  @override
  State<AdvocateClerkNotificationsScreen> createState() => _AdvocateClerkNotificationsScreenState();
}

class _AdvocateClerkNotificationsScreenState extends State<AdvocateClerkNotificationsScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();

  String _targetAudience = 'All Lawyers';
  String _alertType = 'Hearing Change / Adjournment';
  bool _isSending = false;
  List<Map<String, dynamic>> _recentNotifications = [];
  bool _isLoadingRecent = true;

  @override
  void initState() {
    super.initState();
    _fetchRecentNotifications();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecentNotifications() async {
    try {
      final res = await _supabase
          .from('app_notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(10);
      if (mounted) {
        setState(() {
          _recentNotifications = List<Map<String, dynamic>>.from(res);
          _isLoadingRecent = false;
        });
      }
    } catch (e) {
      debugPrint('Non-critical: error fetching recent notifications: $e');
      if (mounted) {
        setState(() => _isLoadingRecent = false);
      }
    }
  }

  Future<void> _sendNotification() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a message body for the notification.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final notificationId = const Uuid().v4();
      await _supabase.from('app_notifications').insert({
        'id': notificationId,
        'target_user': _targetAudience,
        'title': _alertType,
        'message': message,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Notification dispatched successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
        _messageController.clear();
        await _fetchRecentNotifications();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send notification: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications & Alerts',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D256C),
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF7F9FC),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Send New Alert',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0D256C),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 1.5,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Target Audience Dropdown (isExpanded prevents overflow)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _targetAudience,
                    decoration: InputDecoration(
                      labelText: 'Target Audience',
                      labelStyle: GoogleFonts.inter(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      prefixIcon: const Icon(Icons.people_outline, color: Color(0xFF0D256C)),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'All Lawyers',
                        child: Text('All Lawyers', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'Associated Lawyers',
                        child: Text('Associated Lawyers', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'Specific Case Parties',
                        child: Text('Specific Case Parties', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'General Public',
                        child: Text('General Public', overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _targetAudience = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Alert Type Dropdown (isExpanded prevents overflow on long labels)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _alertType,
                    decoration: InputDecoration(
                      labelText: 'Alert Type',
                      labelStyle: GoogleFonts.inter(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      prefixIcon: const Icon(Icons.notification_important_outlined, color: Color(0xFF0D256C)),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Hearing Change / Adjournment',
                        child: Text(
                          'Hearing Change / Adjournment',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Court Announcement',
                        child: Text(
                          'Court Announcement',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Document Request',
                        child: Text(
                          'Document Request',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Urgent Call to Bench',
                        child: Text(
                          'Urgent Call to Bench',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _alertType = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Message Body Field
                  TextField(
                    controller: _messageController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Message Body',
                      labelStyle: GoogleFonts.inter(fontSize: 13),
                      hintText: 'Enter alert details, court numbers, instructions...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 40),
                        child: Icon(Icons.edit_note, color: Color(0xFF0D256C)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendNotification,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send, size: 18),
                      label: Text(
                        _isSending ? 'Sending...' : 'Send Notification',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D256C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Sent Notifications',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0D256C),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF0D256C)),
                onPressed: _fetchRecentNotifications,
                tooltip: 'Refresh Notifications',
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_isLoadingRecent)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_recentNotifications.isEmpty)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.notifications_none, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        'No notifications sent yet.',
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ..._recentNotifications.map((notif) {
              final title = notif['title'] ?? 'Court Alert';
              final desc = notif['message'] ?? '';
              final timeStr = notif['created_at'] != null
                  ? DateFormat('dd MMM, hh:mm a').format(DateTime.parse(notif['created_at']).toLocal())
                  : 'Recent';

              IconData icon = Icons.notifications;
              Color color = const Color(0xFF0D256C);
              if (title.toLowerCase().contains('hearing')) {
                icon = Icons.access_time;
                color = Colors.orange.shade800;
              } else if (title.toLowerCase().contains('announcement')) {
                icon = Icons.campaign;
                color = Colors.blue.shade700;
              } else if (title.toLowerCase().contains('document')) {
                icon = Icons.description;
                color = Colors.teal.shade700;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
                color: Colors.white,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.1),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  title: Text(
                    title,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  subtitle: Text(
                    desc,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  trailing: Text(
                    timeStr,
                    style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
