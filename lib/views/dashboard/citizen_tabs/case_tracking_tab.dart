import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../controllers/request_provider.dart';
import '../../../models/consultation_request.dart';
import '../../../models/legal_case.dart';
import '../../../models/case_update.dart';
import '../../chat/chat_screen.dart';
import '../../../services/lawyer_rating_service.dart';

class CaseTrackingTab extends StatefulWidget {
  const CaseTrackingTab({Key? key}) : super(key: key);

  @override
  _CaseTrackingTabState createState() => _CaseTrackingTabState();
}

class _CaseTrackingTabState extends State<CaseTrackingTab> {
  final _supabase = Supabase.instance.client;

  Future<List<LegalCase>> _fetchMyCourtCases() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    
    final requestProvider = Provider.of<RequestProvider>(context, listen: false);
    final myUsername = requestProvider.currentUsername ?? '';
    
    // Fetch cases where user_id matches OR petitioner matches username (as a fallback)
    if (myUsername.isNotEmpty) {
      final res = await _supabase.from('cases').select().or('user_id.eq.$userId,petitioner.ilike.$myUsername').order('created_at', ascending: false);
      return res.map((c) => LegalCase.fromJson(c)).toList();
    } else {
      final res = await _supabase.from('cases').select().eq('user_id', userId).order('created_at', ascending: false);
      return res.map((c) => LegalCase.fromJson(c)).toList();
    }
  }

  Future<List<CaseUpdate>> _fetchUpdates(String caseId) async {
    final res = await _supabase.from('case_updates').select().eq('case_id', caseId).order('created_at', ascending: true);
    final allUpdates = res.map((u) => CaseUpdate.fromJson(u)).toList();
    // Filter out internal advocate clerk assignment updates for the citizen user in View Timeline
    return allUpdates.where((u) {
      final typeLower = u.updateType.toLowerCase().trim();
      final descLower = u.description.toLowerCase().trim();
      final isClerkAssigned = typeLower.contains('advocate clerk assigned') ||
          typeLower.contains('clerk assigned') ||
          (typeLower.contains('clerk') && typeLower.contains('assign')) ||
          descLower.contains('assigned their advocate clerk') ||
          descLower.contains('advocate clerk assigned') ||
          descLower.contains('clerk assigned');
      return !isClerkAssigned;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          title: Text(
            'My Legal Matters',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: const Color(0xFF0D256C)),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0D256C),
          elevation: 0.5,
          bottom: TabBar(
            labelColor: const Color(0xFF0D256C),
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: const Color(0xFF0D256C),
            indicatorWeight: 3,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 14),
            tabs: const [
              Tab(text: 'Consultations'),
              Tab(text: 'Court Cases'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildConsultationsList(context),
            _buildCourtCasesList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultationsList(BuildContext context) {
    return Consumer<RequestProvider>(
      builder: (context, requestProvider, child) {
        final allCases = requestProvider.requests.toList();
        
        if (allCases.isEmpty) {
          return Center(
            child: Text('You have no consultations right now.', style: GoogleFonts.inter(color: Colors.grey)),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: allCases.map((req) {
            return _buildConsultationTimelineCard(context, req);
          }).toList(),
        );
      },
    );
  }

  Widget _buildCourtCasesList(BuildContext context) {
    return FutureBuilder<List<LegalCase>>(
      future: _fetchMyCourtCases(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading court cases.'));
        }

        final cases = snapshot.data ?? [];
        if (cases.isEmpty) {
          return Center(
            child: Text('You have no active court cases.', style: GoogleFonts.inter(color: Colors.grey)),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: cases.map((c) => _buildCourtCaseCard(context, c)).toList(),
        );
      },
    );
  }

  Widget _buildCourtCaseCard(BuildContext context, LegalCase c) {
    final isClosed = c.status.toLowerCase() == 'closed' || c.status.toLowerCase() == 'completed' || c.status.toLowerCase() == 'resolved';
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    c.title.isNotEmpty ? c.title : (c.caseNumber.isNotEmpty ? c.caseNumber : 'Legal Matter'),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isClosed ? Colors.green[50] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    c.status,
                    style: GoogleFonts.inter(
                      color: isClosed ? Colors.green[700] : Colors.blue[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.gavel, 'Case No: ${c.caseNumber.isNotEmpty ? c.caseNumber : 'Processing'}'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_month, 'Next Hearing: ${c.nextHearingDate != null ? c.nextHearingDate!.toLocal().toString().split(' ')[0] : 'To be announced'}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showCaseUpdates(context, c),
                    icon: const Icon(Icons.history),
                    label: const Text('View Timeline'),
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
            if (isClosed) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showRatingDialog(context, c),
                      icon: const Icon(Icons.star),
                      label: const Text('Rate Lawyer'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[600], foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  void _showCaseUpdates(BuildContext context, LegalCase c) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Timeline: ${c.title}'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<CaseUpdate>>(
            future: _fetchUpdates(c.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final updates = snapshot.data ?? [];
              if (updates.isEmpty) return const Text('No updates yet.');

              return ListView.builder(
                shrinkWrap: true,
                itemCount: updates.length,
                itemBuilder: (context, index) {
                  final u = updates[index];
                  return ListTile(
                    leading: const Icon(Icons.history, color: Colors.blue),
                    title: Text(u.updateType, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('${u.description}\n${DateFormat('dd MMM yyyy, hh:mm a').format(u.createdAt.toLocal())}', style: GoogleFonts.inter(fontSize: 12)),
                    isThreeLine: true,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context, LegalCase c) {
    int rating = 5;
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Rate Your Experience'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('How was your experience with this lawyer/office?'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            rating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Write a brief review (optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final user = Supabase.instance.client.auth.currentUser;
                      if (user == null) return;
                      
                      String? actualLawyerId = c.lawyerId.isNotEmpty ? c.lawyerId : null;
                      if (actualLawyerId == null) {
                        Navigator.pop(ctx);
                        return;
                      }

                      await LawyerRatingService.submitRating(
                        lawyerId: actualLawyerId,
                        citizenId: user.id,
                        rating: rating,
                        reviewText: textController.text.trim(),
                        caseId: c.id,
                      );

                      Navigator.pop(ctx);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted successfully!')));
                    } catch (e) {
                      debugPrint('Error submitting review: $e');
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit review: $e'), backgroundColor: Colors.red));
                    }
                  },
                  child: const Text('Submit'),
                )
              ],
            );
          },
        );
      }
    );
  }

  Widget _buildConsultationTimelineCard(BuildContext context, ConsultationRequest request) {
    final bool isAccepted = request.status == 'Accepted' || request.status == 'Confirmed' || request.status == 'Case Started';
    final bool isRejected = request.status == 'Rejected';
    final bool isAwaiting = request.status == 'Awaiting Confirmation';
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Consultation with ${request.lawyerName}',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAccepted ? Colors.blue[50] : (isRejected ? Colors.red[50] : Colors.orange[50]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isAccepted ? 'Active' : (isRejected ? 'Rejected' : (isAwaiting ? 'Action Required' : 'Pending')),
                    style: GoogleFonts.inter(
                      color: isAccepted ? Colors.blue[700] : (isRejected ? Colors.red[700] : Colors.orange[700]),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.description, 'Issue: ${request.issueDescription}'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_today, 'Requested: ${request.requestedAt.toLocal().toString().split(' ')[0]}'),
            const Divider(height: 32),
            
            if (isAwaiting)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Provider.of<RequestProvider>(context, listen: false).userConfirmsLawyer(request.id, request.lawyerName);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lawyer Confirmed!')));
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Confirm Lawyer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            else
              // Chat Button (Disabled if pending)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isAccepted ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          requestId: request.id,
                          otherPersonName: request.lawyerName,
                          isLawyer: false, // Citizen
                        ),
                      ),
                    );
                  } : null, // Disables button if not accepted
                  icon: const Icon(Icons.chat),
                  label: Text(isAccepted ? 'Chat with Lawyer' : 'Waiting for Lawyer to Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAccepted ? Theme.of(context).primaryColor : Colors.grey[300],
                    foregroundColor: isAccepted ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            Text(
              'Progress Timeline',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _buildTimelineStep(context, 'Request Sent', 'Completed', isCompleted: true),
            _buildTimelineStep(context, 'Lawyer Proceeded', isAccepted || isAwaiting ? 'Completed' : 'Pending', isCompleted: isAccepted || isAwaiting),
            _buildTimelineStep(context, 'User Confirmed', isAccepted ? 'Completed' : 'Awaiting', isCompleted: isAccepted, isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineStep(BuildContext context, String title, String date, {bool isCompleted = false, bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? Theme.of(context).primaryColor : Colors.grey[300],
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                color: isCompleted ? Theme.of(context).primaryColor : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
                  color: isCompleted ? Colors.black87 : Colors.grey[500],
                ),
              ),
              Text(
                date,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
