import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../controllers/notification_provider.dart';
import '../../../controllers/request_provider.dart';
import '../../../models/app_notification.dart';
import '../../../models/legal_case.dart';
import '../../chat/chat_screen.dart';
import 'case_tracking_tab.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  String _formatNotificationTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24 && dt.day == now.day) {
      return 'Today at ${DateFormat('hh:mm a').format(dt)}';
    } else if (diff.inDays == 1 || (diff.inHours < 48 && dt.day == now.day - 1)) {
      return 'Yesterday at ${DateFormat('hh:mm a').format(dt)}';
    } else {
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    }
  }

  void _handleNotificationTap(BuildContext context, AppNotification n) async {
    final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
    await notifProvider.markAsRead(n.id);

    final payload = n.actionPayload;
    if (payload != null && payload.isNotEmpty) {
      // 1. Check if payload matches a consultation request
      final reqProvider = Provider.of<RequestProvider>(context, listen: false);
      final matchedReq = reqProvider.requests.where((r) => r.id == payload).firstOrNull;
      if (matchedReq != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              requestId: matchedReq.id,
              otherPersonName: matchedReq.lawyerName,
              isLawyer: false,
            ),
          ),
        );
        return;
      }

      // 2. Check if payload is a case in the 'cases' table
      try {
        final caseRow = await Supabase.instance.client
            .from('cases')
            .select()
            .eq('id', payload)
            .maybeSingle();

        if (caseRow != null && context.mounted) {
          final legalCase = LegalCase.fromJson(caseRow);
          _showCaseUpdateModal(context, n, legalCase);
          return;
        }
      } catch (e) {
        debugPrint('Could not resolve case for notification: $e');
      }
    }

    // Default: Show general notification modal
    _showGeneralNotificationDialog(context, n);
  }

  void _showCaseUpdateModal(BuildContext context, AppNotification n, LegalCase legalCase) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D256C).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.gavel, color: Color(0xFF0D256C), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0D256C),
                        ),
                      ),
                      Text(
                        _formatNotificationTime(n.timestamp),
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Text(
              'Case: ${legalCase.title}',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
            ),
            if (legalCase.caseNumber.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Case / CNR: ${legalCase.caseNumber}',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
            if (legalCase.courtName != null && legalCase.courtName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Court: ${legalCase.courtName}',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Text(
                n.message,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.blue.shade900, height: 1.4),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CaseTrackingTab()),
                  );
                },
                icon: const Icon(Icons.history_edu),
                label: const Text('Open Case Tracking & Timeline'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D256C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showGeneralNotificationDialog(BuildContext context, AppNotification n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(n.title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n.message, style: GoogleFonts.inter(fontSize: 14, height: 1.4)),
            const SizedBox(height: 12),
            Text(
              _formatNotificationTime(n.timestamp),
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Dismiss')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final username = user?.userMetadata?['username'] ?? 'Citizen';

    // Mark as read and synchronize notifications across identifiers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
      notifProvider.markAllAsRead(username, userId: user?.id, email: user?.email);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D256C),
        elevation: 1,
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notifProvider, child) {
          final notifications = notifProvider.notifications;

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'No notifications yet',
                    style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Case filings, hearings, and clerk updates will appear here.',
                    style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final n = notifications[index];
              final isHearing = n.title.toLowerCase().contains('hearing');
              final isFiling = n.title.toLowerCase().contains('file') || n.title.toLowerCase().contains('filing') || n.title.toLowerCase().contains('cnr');

              return InkWell(
                onTap: () => _handleNotificationTap(context, n),
                borderRadius: BorderRadius.circular(14),
                child: Card(
                  elevation: n.isRead ? 0 : 2,
                  color: n.isRead ? Colors.white : Colors.blue.shade50.withValues(alpha: 0.7),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: n.isRead ? Colors.grey.shade200 : const Color(0xFF0D256C).withValues(alpha: 0.3),
                      width: n.isRead ? 1 : 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isHearing 
                                ? Colors.amber.shade100 
                                : isFiling 
                                    ? Colors.green.shade100 
                                    : const Color(0xFF0D256C).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isHearing 
                                ? Icons.calendar_month 
                                : isFiling 
                                    ? Icons.gavel 
                                    : Icons.notifications_active,
                            color: isHearing 
                                ? Colors.amber.shade900 
                                : isFiling 
                                    ? Colors.green.shade800 
                                    : const Color(0xFF0D256C),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      n.title,
                                      style: GoogleFonts.inter(
                                        fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
                                        fontSize: 15,
                                        color: const Color(0xFF0D256C),
                                      ),
                                    ),
                                  ),
                                  if (!n.isRead) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.blueAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n.message,
                                style: GoogleFonts.inter(
                                  color: Colors.grey.shade800,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatNotificationTime(n.timestamp),
                                style: GoogleFonts.inter(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
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
