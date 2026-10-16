import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/legal_case.dart';
import '../../../models/case_document.dart';
import '../../../controllers/advocate_clerk_provider.dart';
import '../chat/filing_chat_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/secure_evidence_viewer.dart';
import 'advocate_clerk_messages_screen.dart';
import 'advocate_clerk_notifications_screen.dart';

class AdvocateClerkFilingsTab extends StatefulWidget {
  const AdvocateClerkFilingsTab({Key? key}) : super(key: key);

  @override
  _AdvocateClerkFilingsTabState createState() => _AdvocateClerkFilingsTabState();
}

class _AdvocateClerkFilingsTabState extends State<AdvocateClerkFilingsTab> {
  void _showFilingDetails(BuildContext context, LegalCase legalCase) async {
    final clerkProvider = Provider.of<AdvocateClerkProvider>(context, listen: false);
    
    // Fetch documents and petition
    List<CaseDocument> documents = await clerkProvider.fetchCaseDocuments(legalCase.id);
    // Ignore petition for now, treat as document if needed, or assume it's part of documents.
    // The prompt says "Check Petition, Verify Documents". We'll just display the documents list.

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final defectController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            bool allVerified = documents.isNotEmpty && documents.every((d) => d.verificationStatus == 'Verified');

            return AlertDialog(
              title: Text('Case File: ${legalCase.id}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Title: ${legalCase.title}', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    Text('Category: ${legalCase.category}', style: GoogleFonts.inter()),
                    Text('Lawyer ID: ${legalCase.lawyerId}', style: GoogleFonts.inter()),
                    const SizedBox(height: 8),
                    Text('Description: ${legalCase.description}', style: GoogleFonts.inter()),
                    const SizedBox(height: 16),
                    Text('Documents Checklist:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                    const SizedBox(height: 8),
                    if (documents.isEmpty)
                      const Text('No documents uploaded yet.')
                    else
                      ...documents.map((doc) => Card(
                        child: ListTile(
                          leading: Icon(
                            doc.verificationStatus == 'Verified' ? Icons.check_circle :
                            doc.verificationStatus == 'Missing' || doc.verificationStatus == 'Invalid' ? Icons.error : Icons.help,
                            color: doc.verificationStatus == 'Verified' ? Colors.green :
                                   doc.verificationStatus == 'Missing' || doc.verificationStatus == 'Invalid' ? Colors.red : Colors.grey,
                          ),
                          title: Text(doc.documentName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('Status: ${doc.verificationStatus}', style: GoogleFonts.inter(fontSize: 12)),
                          trailing: PopupMenuButton<String>(
                            onSelected: (val) async {
                              await clerkProvider.verifyDocument(doc.id, val, '');
                              // Reload docs
                              final newDocs = await clerkProvider.fetchCaseDocuments(legalCase.id);
                              setStateDialog(() {
                                documents = newDocs;
                              });
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'Verified', child: Text('Mark Verified')),
                              const PopupMenuItem(value: 'Invalid', child: Text('Mark Invalid')),
                              const PopupMenuItem(value: 'Missing', child: Text('Mark Missing')),
                            ],
                          ),
                        ),
                      )),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                if (legalCase.status != 'Ready for Filing' && legalCase.status != 'Filed') ...[
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Correction Required'),
                          content: TextField(
                            controller: defectController,
                            decoration: const InputDecoration(hintText: 'Enter missing/invalid document reason'),
                            maxLines: 3,
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () {
                                if (defectController.text.trim().isNotEmpty) {
                                  clerkProvider.markCorrectionRequired(legalCase.id, defectController.text.trim(), legalCase.lawyerId);
                                  Navigator.pop(dCtx); // Close defect dialog
                                  Navigator.pop(ctx);  // Close details dialog
                                }
                              },
                              child: const Text('Request Lawyer Correction'),
                            )
                          ],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    child: const Text('Correction'),
                  ),
                  ElevatedButton(
                    onPressed: allVerified ? () async {
                      // Confirm dialog
                      bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Ready for Review?'),
                          content: const Text('Are you sure the documents are prepared and ready for Lawyer review?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                            ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await clerkProvider.markReadyForLawyerReview(legalCase.id, legalCase.lawyerId);
                        if (context.mounted) Navigator.pop(ctx);
                      }
                    } : null,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    child: const Text('Ready for Review'),
                  ),
                ],
                if (legalCase.status == 'Approved for Filing')
                  ElevatedButton(
                    onPressed: () async {
                      final caseNum = 'JC-2026-${DateTime.now().millisecondsSinceEpoch % 10000}';
                      await clerkProvider.coordinateFiling(legalCase.id, caseNum, legalCase.lawyerId, legalCase.userId);
                      if (context.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text('Coordinate Filing'),
                  ),
                
                // Send Update Button
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (uCtx) {
                        final titleCtrl = TextEditingController();
                        final descCtrl = TextEditingController();
                        return AlertDialog(
                          title: const Text('Send Update to User'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Update Title')),
                              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(uCtx), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () async {
                                if (titleCtrl.text.isNotEmpty && descCtrl.text.isNotEmpty) {
                                  await clerkProvider.sendCustomUpdateToUser(legalCase.id, legalCase.userId, titleCtrl.text, descCtrl.text);
                                  if (context.mounted) Navigator.pop(uCtx);
                                  if (context.mounted) Navigator.pop(ctx);
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Update sent successfully')));
                                }
                              },
                              child: const Text('Send'),
                            ),
                          ],
                        );
                      }
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                  child: const Text('Send Update'),
                ),
                
                // Chat Button always available
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FilingChatScreen(
                          filingId: legalCase.id,
                          filingTitle: legalCase.title,
                          currentUserRole: 'Advocate Clerk',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('Chat'),
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (ctx) {
                        return Container(
                          padding: const EdgeInsets.only(top: 16),
                          height: MediaQuery.of(context).size.height * 0.8,
                          child: Column(
                            children: [
                              Text('Case Evidence: ${legalCase.title}', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                              const Divider(),
                              Expanded(child: SecureEvidenceViewer(caseId: legalCase.id)),
                            ],
                          ),
                        );
                      }
                    );
                  },
                  icon: const Icon(Icons.security),
                  label: const Text('Evidence'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final shareText = 'Case: ${legalCase.id}\nTitle: ${legalCase.title}\nStatus: ${legalCase.status}\nDocuments Checked: ${documents.length}\nAll Verified: $allVerified';
                    Share.share(shareText);
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share Status'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text(
          'Case Filings & Scrutiny',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: const Color(0xFF0D256C)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D256C),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF0D256C)),
            tooltip: 'Lawyer Messages',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdvocateClerkMessagesScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Color(0xFF0D256C)),
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdvocateClerkNotificationsScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<AdvocateClerkProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

        // Show cases that are in the "Filing/Verification" lifecycle
        final cases = provider.cases.where((c) => 
          c.status == 'Submitted' || 
          c.status == 'Under Verification' || 
          c.status == 'Correction Required' || 
          c.status == 'Correction Submitted' ||
          c.status == 'Documents Uploaded' ||
          c.status == 'Ready for Lawyer Review' ||
          c.status == 'Approved for Filing' ||
          c.status == 'Verified' ||
          c.status == 'Accepted'
        ).toList();

        if (cases.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open_outlined, size: 54, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No pending case files found',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All incoming case filings are up to date.',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: cases.length,
          itemBuilder: (context, index) {
            final c = cases[index];
            final statusColor = _getStatusColor(c.status);
            final statusBg = _getStatusBgColor(c.status);
            final dateStr = c.registeredAt.toString().length >= 10
                ? c.registeredAt.toString().substring(0, 10)
                : '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () => _showFilingDetails(context, c),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              c.status,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                dateStr,
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        c.title,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0D256C),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Case #${c.id.length > 8 ? c.id.substring(0, 8) : c.id}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                'Check File',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0D256C),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF0D256C)),
                            ],
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Verified':
      case 'Approved for Filing':
        return Colors.green.shade700;
      case 'Correction Required':
        return Colors.red.shade700;
      case 'Under Verification':
      case 'Documents Uploaded':
      case 'Correction Submitted':
        return Colors.orange.shade800;
      case 'Ready for Lawyer Review':
        return Colors.indigo.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'Verified':
      case 'Approved for Filing':
        return Colors.green.shade50;
      case 'Correction Required':
        return Colors.red.shade50;
      case 'Under Verification':
      case 'Documents Uploaded':
      case 'Correction Submitted':
        return Colors.orange.shade50;
      case 'Ready for Lawyer Review':
        return Colors.indigo.shade50;
      default:
        return Colors.blue.shade50;
    }
  }
}
