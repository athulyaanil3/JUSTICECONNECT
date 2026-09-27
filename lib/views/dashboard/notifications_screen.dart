import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/notification_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
      if (notifProvider.currentTargetUser != null) {
        // It's already fetched by the Dashboard, but just in case we can fetch again
        // or just mark as read here if we wanted. But it's already listening.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () {
               final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
               if (notifProvider.currentTargetUser != null) {
                 notifProvider.markAllAsRead(notifProvider.currentTargetUser!);
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All marked as read')));
               }
            },
          )
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, child) {
          final notifications = notificationProvider.notifications;
          if (notifications.isEmpty) {
            return Center(
              child: Text('No new notifications.', style: GoogleFonts.inter(color: Colors.grey)),
            );
          }
          
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final n = notifications[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: n.isRead ? Colors.grey[200] : Colors.blue[50],
                  child: Icon(
                    n.isRead ? Icons.notifications_none : Icons.notifications_active,
                    color: n.isRead ? Colors.grey : Colors.blue,
                  ),
                ),
                title: Text(n.title, style: GoogleFonts.inter(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                subtitle: Text(n.message, style: GoogleFonts.inter(fontSize: 13)),
                trailing: Text(
                  _formatTimeAgo(n.timestamp),
                  style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
