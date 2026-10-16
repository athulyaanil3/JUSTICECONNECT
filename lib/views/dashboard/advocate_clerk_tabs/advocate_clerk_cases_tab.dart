import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/legal_case.dart';
import '../../../models/case_update.dart';
import '../../../controllers/advocate_clerk_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../chat/filing_chat_screen.dart';
import 'advocate_clerk_messages_screen.dart';
import 'advocate_clerk_notifications_screen.dart';

class AdvocateClerkCasesTab extends StatefulWidget {
  const AdvocateClerkCasesTab({Key? key}) : super(key: key);

  @override
  _AdvocateClerkCasesTabState createState() => _AdvocateClerkCasesTabState();
}

class _AdvocateClerkCasesTabState extends State<AdvocateClerkCasesTab> {
  String _searchQuery = '';

  void _showCaseDetails(BuildContext context, LegalCase legalCase) async {
    final clerkProvider = Provider.of<AdvocateClerkProvider>(context, listen: false);
    List<CaseUpdate> updates = await clerkProvider.fetchCaseUpdates(legalCase.id);
    
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final updateTypeController = TextEditingController();
        final descController = TextEditingController();
        final closeReasonController = TextEditingController();
        
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Case: ${legalCase.caseNumber.isNotEmpty ? legalCase.caseNumber : legalCase.id}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Title: ${legalCase.title}', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      Text('Status: ${legalCase.status}', style: GoogleFonts.inter(color: Theme.of(context).primaryColor)),
                      const SizedBox(height: 16),
                      Text('Case Timeline:', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (updates.isEmpty)
                        const Text('No updates yet.')
                      else
                        ...updates.map((u) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.circle, size: 12, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(u.updateType, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(u.description, style: GoogleFonts.inter(fontSize: 12)),
                                    Text(DateFormat('dd MMM yyyy, hh:mm a').format(u.createdAt.toLocal()), style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                if (legalCase.status != 'Closed' && legalCase.status != 'Dismissed') ...[
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Add Case Update & Status'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: updateTypeController,
                                decoration: const InputDecoration(hintText: 'New Status (e.g. In Progress)'),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: descController,
                                decoration: const InputDecoration(hintText: 'Description'),
                                maxLines: 3,
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () async {
                                if (updateTypeController.text.isNotEmpty && descController.text.isNotEmpty) {
                                  await clerkProvider.updateCaseStatusAndAddUpdate(
                                    legalCase.id, 
                                    updateTypeController.text, 
                                    updateTypeController.text, // Use the new status as the update type too
                                    descController.text
                                  );
                                  final newUpdates = await clerkProvider.fetchCaseUpdates(legalCase.id);
                                  setStateDialog(() {
                                    updates = newUpdates;
                                    // Hack to update UI for the status text in the dialog
                                    // (Ideally, we'd refetch the single case or re-build the whole tab, but this works for demo)
                                  });
                                  if (context.mounted) Navigator.pop(dCtx);
                                }
                              },
                              child: const Text('Save'),
                            )
                          ],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    child: const Text('Add Update'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Close or Dismiss Case'),
                          content: TextField(
                            controller: closeReasonController,
                            decoration: const InputDecoration(hintText: 'Reason for closure/dismissal'),
                            maxLines: 3,
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () async {
                                if (closeReasonController.text.isNotEmpty) {
                                  await clerkProvider.addClosureRemarks(legalCase.id, closeReasonController.text, 'Dismissed', legalCase.lawyerId, legalCase.userId);
                                  if (context.mounted) {
                                    Navigator.pop(dCtx);
                                    Navigator.pop(ctx);
                                  }
                                }
                              },
                              child: const Text('Dismiss'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              onPressed: () async {
                                if (closeReasonController.text.isNotEmpty) {
                                  await clerkProvider.addClosureRemarks(legalCase.id, closeReasonController.text, 'Closed', legalCase.lawyerId, legalCase.userId);
                                  if (context.mounted) {
                                    Navigator.pop(dCtx);
                                    Navigator.pop(ctx);
                                  }
                                }
                              },
                              child: const Text('Close Case'),
                            )
                          ],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white),
                    child: const Text('Close Case'),
                  ),
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
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('Chat with Lawyer'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D256C), foregroundColor: Colors.white),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      final shareText = 'Case: ${legalCase.caseNumber.isNotEmpty ? legalCase.caseNumber : legalCase.id}\nTitle: ${legalCase.title}\nStatus: ${legalCase.status}\n\nLatest Updates:\n' + 
                        (updates.isEmpty ? 'No updates yet.' : updates.map((u) => '${u.updateType}: ${u.description}').join('\n'));
                      Share.share(shareText);
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share Status'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  ),
                ]
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text(
          'Court Cases Repository',
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

        final cases = provider.cases.where((c) {
          final query = _searchQuery.toLowerCase();
          final matchesSearch = c.caseNumber.toLowerCase().contains(query) || c.title.toLowerCase().contains(query);
          return matchesSearch;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search court cases...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              ),
            ),
            Expanded(
              child: cases.isEmpty
                  ? Center(child: Text('No active cases found.', style: GoogleFonts.inter(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: cases.length,
                      itemBuilder: (context, index) {
                        final c = cases[index];
                        final isClosed = c.status == 'Closed' || c.status == 'Dismissed';
                        final isProceeding = c.status == 'Proceeding' || c.status == 'Hearing Scheduled';

                        final statusColor = isClosed
                            ? Colors.grey.shade700
                            : isProceeding
                                ? Colors.teal.shade700
                                : const Color(0xFF0D256C);

                        final statusBg = isClosed
                            ? Colors.grey.shade100
                            : isProceeding
                                ? Colors.teal.shade50
                                : const Color(0xFFE8EAF6);

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
                            onTap: () => _showCaseDetails(context, c),
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
                                      if (c.courtName != null && c.courtName!.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              c.courtName!,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade700,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                      ],
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
                                      Expanded(
                                        child: Text(
                                          'CNR: ' + (c.caseNumber.isNotEmpty ? c.caseNumber : 'Not Assigned'),
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF0D256C)),
                                            tooltip: 'Chat with Lawyer',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => FilingChatScreen(
                                                    filingId: c.id,
                                                    filingTitle: c.title,
                                                    currentUserRole: 'Advocate Clerk',
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.arrow_forward_ios, size: 13, color: Color(0xFF0D256C)),
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
                    ),
            ),
          ],
        );
      },
    ),
  );
}
}
