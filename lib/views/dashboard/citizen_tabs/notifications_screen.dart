import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../controllers/notification_provider.dart';
import '../../../controllers/request_provider.dart';
import '../../chat/chat_screen.dart';

import '../../../controllers/notification_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final username = user?.userMetadata?['username'] ?? 'Citizen';

    // Mark as read when opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).markAllAsRead(username);
    });

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).primaryColor,
        elevation: 1,
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notifProvider, child) {
          final notifications = notifProvider.notifications;

          if (notifications.isEmpty) {
            return Center(
              child: Text(
                'No notifications yet.',
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final n = notifications[index];
              return InkWell(
                onTap: () {
                  if (n.actionPayload != null) {
                    final request = Provider.of<RequestProvider>(context, listen: false)
                        .requests
                        .firstWhere((r) => r.id == n.actionPayload, orElse: () => throw Exception('Request not found'));

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          requestId: request.id,
                          otherPersonName: request.lawyerName,
                          isLawyer: false,
                        ),
                      ),
                    );
                  }
                },
                child: Card(
                elevation: n.isRead ? 0 : 2,
                color: n.isRead ? Colors.white : Colors.blue[50],
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: n.isRead ? Colors.grey[200]! : Colors.blue[200]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.notifications_active, color: Theme.of(context).primaryColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.title,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              n.message,
                              style: GoogleFonts.inter(
                                color: Colors.grey[800],
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Just now', // In real app, format n.timestamp
                              style: GoogleFonts.inter(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      ),
    );
  }
}
