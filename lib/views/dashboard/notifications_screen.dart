import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../controllers/notification_provider.dart';
import '../../controllers/request_provider.dart';
import '../../controllers/lawyer_provider.dart';
import '../../models/app_notification.dart';
import '../../models/consultation_request.dart';
import '../chat/chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../shared/document_viewer_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
      final user = _supabase.auth.currentUser;
      final target = notifProvider.currentTargetUser ?? user?.userMetadata?['username'] ?? user?.email ?? 'User';
      notifProvider.fetchNotifications(target, userId: user?.id, email: user?.email);
      Provider.of<RequestProvider>(context, listen: false).fetchRequests();
    });
  }

  Future<void> _handleNotificationTap(BuildContext context, AppNotification n) async {
    final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
    await notifProvider.markAsRead(n.id);

    // 1. Check if notification is a Clerk Request
    final isClerkNotification = n.title.toLowerCase().contains('clerk') || 
                                n.message.toLowerCase().contains('advocate clerk');
    if (isClerkNotification) {
      try {
        Map<String, dynamic>? clerkProfile;
        if (n.actionPayload != null && n.actionPayload!.isNotEmpty) {
          clerkProfile = await _supabase.from('profiles').select().eq('id', n.actionPayload!).maybeSingle();
        }
        if (clerkProfile == null) {
          final user = _supabase.auth.currentUser;
          if (user != null) {
            final clerks = await _supabase
                .from('profiles')
                .select()
                .eq('role', 'Advocate Clerk')
                .eq('associated_lawyer_id', user.id)
                .order('created_at', ascending: false);
            if (clerks.isNotEmpty) {
              clerkProfile = clerks.first;
            }
          }
        }
        if (clerkProfile != null && mounted) {
          _showClerkReviewModal(context, clerkProfile);
          return;
        }
      } catch (e) {
        debugPrint('Error finding clerk profile for notification: $e');
      }
    }

    if (n.actionPayload != null && n.actionPayload!.isNotEmpty) {
      final reqProvider = Provider.of<RequestProvider>(context, listen: false);
      
      // 1. Look in cached requests
      ConsultationRequest? matchedRequest;
      try {
        matchedRequest = reqProvider.requests.firstWhere(
          (r) => r.id == n.actionPayload,
        );
      } catch (_) {}

      // 2. If not found in cache, fetch directly from Supabase
      if (matchedRequest == null) {
        try {
          final row = await _supabase
              .from('consultation_requests')
              .select()
              .eq('id', n.actionPayload!)
              .maybeSingle();

          if (row != null) {
            matchedRequest = ConsultationRequest(
              id: row['id'],
              citizenName: row['citizen_name'] ?? 'Citizen',
              lawyerName: row['lawyer_name'] ?? 'Lawyer',
              issueDescription: row['issue_description'] ?? '',
              status: row['status'] ?? 'Pending',
              requestedAt: DateTime.tryParse(row['requested_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
              messages: [],
            );
          }
        } catch (e) {
          debugPrint('Error looking up request for notification: $e');
        }
      }

      if (matchedRequest != null && mounted) {
        _showRequestDetailsSheet(context, matchedRequest);
        return;
      }
    }

    // Default: Show general notification details dialog
    if (mounted) {
      _showGeneralNotificationDialog(context, n);
    }
  }

  void _openClerkDocument(BuildContext context, String? docName, String clerkName) async {
    if (docName == null || docName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No document uploaded')),
      );
      return;
    }

    try {
      final url = Supabase.instance.client.storage.from('documents').getPublicUrl(docName);
      final ext = docName.split('.').last.toLowerCase();
      final isPdf = ext == 'pdf';
      final isImage = ext == 'jpg' || ext == 'jpeg' || ext == 'png';

      if (isPdf || isImage) {
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullScreenDocumentViewer(
              url: url,
              isPdf: isPdf,
              title: '$clerkName - Verification Document',
            ),
          ),
        );
      } else {
        final uri = Uri.parse(url);
        bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open file in external application.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading document: $e')),
        );
      }
    }
  }

  Widget _buildClerkInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey[700], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.black87, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showClerkReviewModal(BuildContext context, Map<String, dynamic> clerk) {
    final docName = clerk['verification_document'];
    String displayName = 'No document uploaded';
    if (docName != null && docName.toString().isNotEmpty) {
      final parts = docName.toString().split('_');
      if (parts.length > 3) {
        displayName = parts.sublist(3).join('_');
      } else if (parts.length > 2) {
        displayName = parts.sublist(2).join('_');
      } else {
        displayName = docName.toString();
      }
    }
    final ext = (docName != null) ? docName.toString().split('.').last.toLowerCase() : '';
    final isPdf = ext == 'pdf';
    final isImage = ext == 'jpg' || ext == 'jpeg' || ext == 'png';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.badge, color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Advocate Clerk Request',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            'Verification & Office Assignment',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      _buildClerkInfoRow('Name', clerk['username'] ?? 'Unknown'),
                      const SizedBox(height: 8),
                      _buildClerkInfoRow('Email', clerk['email'] ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildClerkInfoRow('Court ID', clerk['court_id'] ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildClerkInfoRow('District', clerk['court_district'] ?? 'N/A'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Uploaded Verification Document',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: docName != null
                      ? () => _openClerkDocument(context, docName, clerk['username'] ?? 'Clerk')
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: docName != null ? Colors.blue.withOpacity(0.08) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: docName != null ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPdf ? Icons.picture_as_pdf : (isImage ? Icons.image : Icons.description),
                          color: docName != null ? (isPdf ? Colors.red : (isImage ? Colors.blue : Colors.orange)) : Colors.grey,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: GoogleFonts.inter(
                                  color: docName != null ? Colors.blue[800] : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  decoration: docName != null ? TextDecoration.underline : TextDecoration.none,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (docName != null)
                                Text(
                                  'Tap or click eye to view document in-app',
                                  style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                        if (docName != null)
                          IconButton(
                            icon: const Icon(Icons.visibility, color: Colors.blue),
                            tooltip: 'View Document',
                            onPressed: () => _openClerkDocument(context, docName, clerk['username'] ?? 'Clerk'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            await _supabase.from('profiles').update({'is_verified': false}).eq('id', clerk['id']);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Clerk Rejected.')),
                              );
                            }
                          } catch (e) {
                            debugPrint('Error rejecting clerk: $e');
                          }
                        },
                        child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            await _supabase.from('profiles').update({'is_verified': true}).eq('id', clerk['id']);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Clerk Approved Successfully!'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            debugPrint('Error approving clerk: $e');
                          }
                        },
                        child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRequestDetailsSheet(BuildContext context, ConsultationRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer<RequestProvider>(
          builder: (context, reqProvider, _) {
            // Find live updated request if available
            final liveRequest = reqProvider.requests.firstWhere(
              (r) => r.id == request.id,
              orElse: () => request,
            );

            final status = liveRequest.status;
            final isPending = status == 'Pending';
            final isAwaiting = status == 'Awaiting Confirmation';
            final isAcceptedOrConfirmed = status == 'Accepted' || status == 'Confirmed';
            final isCaseStarted = status == 'Case Started';
            final isRejected = status == 'Rejected';

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header with Status Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.assignment, color: Theme.of(context).primaryColor, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Consultation Request',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: const Color(0xFF1A1A1A),
                                  ),
                                ),
                                Text(
                                  DateFormat('dd MMM yyyy, hh:mm a').format(liveRequest.requestedAt),
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ],
                        ),
                        _buildStatusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Citizen Details Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.15),
                                child: Text(
                                  liveRequest.citizenName.isNotEmpty ? liveRequest.citizenName[0].toUpperCase() : 'C',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      liveRequest.citizenName,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Text(
                                      'Potential Client',
                                      style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Text(
                            'Legal Matter / Issue:',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            liveRequest.issueDescription.isNotEmpty
                                ? liveRequest.issueDescription
                                : 'No description provided by client.',
                            style: GoogleFonts.inter(fontSize: 14, color: Colors.black87, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Status Guidance Notice
                    if (isPending)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tap "Take / Proceed Request" to accept this consultation. The citizen will be notified to confirm.',
                                style: GoogleFonts.inter(fontSize: 12.5, color: Colors.orange[900]),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isAwaiting)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.hourglass_empty, color: Colors.blue, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'You have proceeded with this request. Waiting for the citizen to confirm the lawyer.',
                                style: GoogleFonts.inter(fontSize: 12.5, color: Colors.blue[900]),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isAcceptedOrConfirmed)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Citizen confirmed! You can now chat directly or take this case formally into court.',
                                style: GoogleFonts.inter(fontSize: 12.5, color: Colors.green[900]),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isCaseStarted)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.gavel, color: Colors.purple, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This consultation has been converted into a formal case.',
                                style: GoogleFonts.inter(fontSize: 12.5, color: Colors.purple[900]),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isRejected)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This consultation request has been rejected.',
                                style: GoogleFonts.inter(fontSize: 12.5, color: Colors.red[900]),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Action Buttons based on status
                    if (isPending) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await reqProvider.updateRequestStatus(liveRequest.id, 'Rejected');
                                
                                final notification = AppNotification(
                                  id: const Uuid().v4(),
                                  title: 'Request Rejected',
                                  message: '${liveRequest.lawyerName} is unable to take your consultation request at this time.',
                                  timestamp: DateTime.now(),
                                  actionPayload: liveRequest.id,
                                );
                                if (context.mounted) {
                                  Provider.of<NotificationProvider>(context, listen: false)
                                      .addNotification(notification, liveRequest.citizenName);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Request rejected.')),
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await reqProvider.lawyerProceedsRequest(liveRequest.id, liveRequest.citizenName);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Request proceeded! Awaiting citizen confirmation.'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.thumb_up_alt_outlined, size: 20),
                              label: const Text('Take / Proceed Request'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (isAcceptedOrConfirmed) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      requestId: liveRequest.id,
                                      otherPersonName: liveRequest.citizenName,
                                      isLawyer: true,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.chat_outlined),
                              label: const Text('Chat'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showTakeCaseDialog(context, liveRequest);
                              },
                              icon: const Icon(Icons.gavel),
                              label: const Text('Take Formal Case'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  requestId: liveRequest.id,
                                  otherPersonName: liveRequest.citizenName,
                                  isLawyer: true,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat),
                          label: const Text('Open Messages'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTakeCaseDialog(BuildContext context, ConsultationRequest request) {
    final titleController = TextEditingController(text: 'Case for ${request.citizenName}');
    final categoryController = TextEditingController();
    final lawyerProvider = Provider.of<LawyerProvider>(context, listen: false);
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.gavel, color: Colors.green, size: 26),
                const SizedBox(width: 10),
                Text('Take Case', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Convert this consultation for "${request.citizenName}" into a formal court case.',
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Case Title',
                      hintText: 'e.g. Property Dispute',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    enabled: !isSubmitting,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: categoryController,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      hintText: 'e.g. Civil, Criminal, Family',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    enabled: !isSubmitting,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  if (titleController.text.trim().isEmpty || categoryController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill out all fields.')),
                    );
                    return;
                  }

                  setStateDialog(() => isSubmitting = true);

                  try {
                    // 1. Submit Case
                    await lawyerProvider.submitNewCaseFile(
                      titleController.text.trim(),
                      categoryController.text.trim(),
                      request.issueDescription,
                      request.citizenName,
                    );

                    // 2. Notify Citizen
                    final notification = AppNotification(
                      id: const Uuid().v4(),
                      title: 'Case Started!',
                      message: '${request.lawyerName} has officially taken your case: ${titleController.text.trim()}.',
                      timestamp: DateTime.now(),
                      actionPayload: request.id,
                    );

                    if (context.mounted) {
                      Provider.of<NotificationProvider>(context, listen: false)
                          .addNotification(notification, request.citizenName);
                      // 3. Update Request Status
                      await Provider.of<RequestProvider>(context, listen: false)
                          .updateRequestStatus(request.id, 'Case Started');

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Case officially taken and started!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      setStateDialog(() => isSubmitting = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to submit case: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Take Case'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showGeneralNotificationDialog(BuildContext context, AppNotification n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(n.title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n.message, style: GoogleFonts.inter(fontSize: 14)),
            const SizedBox(height: 16),
            Text(
              DateFormat('dd MMM yyyy, hh:mm a').format(n.timestamp),
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;

    switch (status) {
      case 'Accepted':
      case 'Confirmed':
        bg = Colors.green[50]!;
        fg = Colors.green[700]!;
        break;
      case 'Awaiting Confirmation':
        bg = Colors.blue[50]!;
        fg = Colors.blue[700]!;
        break;
      case 'Case Started':
        bg = Colors.purple[50]!;
        fg = Colors.purple[700]!;
        break;
      case 'Rejected':
        bg = Colors.red[50]!;
        fg = Colors.red[700]!;
        break;
      default:
        bg = Colors.orange[50]!;
        fg = Colors.orange[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).primaryColor,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () {
              final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
              if (notifProvider.currentTargetUser != null) {
                notifProvider.markAllAsRead(notifProvider.currentTargetUser!);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All notifications marked as read')),
                );
              }
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, child) {
          final notifications = notificationProvider.notifications;
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No new notifications',
                    style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final n = notifications[index];
              final isClerkRelated = n.title.toLowerCase().contains('clerk') ||
                  n.message.toLowerCase().contains('advocate clerk');
              final isRequestRelated = !isClerkRelated && ((n.actionPayload != null && n.actionPayload!.isNotEmpty) ||
                  n.title.toLowerCase().contains('request') ||
                  n.title.toLowerCase().contains('consultation'));

              return Card(
                elevation: n.isRead ? 0.5 : 2,
                color: n.isRead ? Colors.white : Colors.blue.shade50.withOpacity(0.4),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: n.isRead ? Colors.grey[200]! : Theme.of(context).primaryColor.withOpacity(0.3),
                    width: n.isRead ? 1 : 1.5,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _handleNotificationTap(context, n),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isClerkRelated
                                    ? Colors.blue.withOpacity(0.12)
                                    : (isRequestRelated
                                        ? Colors.orange.withOpacity(0.12)
                                        : Theme.of(context).primaryColor.withOpacity(0.1)),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isClerkRelated
                                    ? Icons.badge_outlined
                                    : (isRequestRelated
                                        ? Icons.person_add_alt_1
                                        : (n.isRead ? Icons.notifications_none : Icons.notifications_active)),
                                color: isClerkRelated
                                    ? Colors.blue[800]
                                    : (isRequestRelated
                                        ? Colors.orange[800]
                                        : (n.isRead ? Colors.grey[600] : Theme.of(context).primaryColor)),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          n.title,
                                          style: GoogleFonts.inter(
                                            fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
                                            fontSize: 15,
                                            color: const Color(0xFF1A1A1A),
                                          ),
                                        ),
                                      ),
                                      if (!n.isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(left: 6),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).primaryColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    n.message,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.grey[800],
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatTimeAgo(n.timestamp),
                                        style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 11.5),
                                      ),
                                      if (isClerkRelated)
                                        Row(
                                          children: [
                                            Text(
                                              'Tap to review clerk & doc',
                                              style: GoogleFonts.inter(
                                                color: Colors.blue[700],
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.arrow_forward_ios,
                                              size: 11,
                                              color: Colors.blue[700],
                                            ),
                                          ],
                                        )
                                      else if (isRequestRelated)
                                        Row(
                                          children: [
                                            Text(
                                              'Tap to take request',
                                              style: GoogleFonts.inter(
                                                color: Theme.of(context).primaryColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.arrow_forward_ios,
                                              size: 11,
                                              color: Theme.of(context).primaryColor,
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
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

  String _formatTimeAgo(DateTime time) {
    final localTime = time.toLocal();
    final diff = DateTime.now().difference(localTime);
    if (diff.isNegative || diff.inSeconds < 60) return 'Just now';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
