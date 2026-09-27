import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../controllers/request_provider.dart';
import '../../../models/consultation_request.dart';
import '../../../models/legal_case.dart';
import '../../../models/case_update.dart';
import '../../chat/chat_screen.dart';
import '../../widgets/causelist_card.dart';

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
    return res.map((u) => CaseUpdate.fromJson(u)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: Text(
            'My Legal Matters',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Theme.of(context).primaryColor,
          elevation: 0,
          bottom: TabBar(
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
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
    // If the case is officially registered (has a case number), use the Causelist view
    if (c.caseNumber.isNotEmpty) {
      final isClosed = c.status.toLowerCase() == 'closed' || c.status.toLowerCase() == 'completed' || c.status.toLowerCase() == 'resolved';
      return CauselistCard(
        legalCase: c,
        onTap: () => _showCaseUpdates(context, c),
        bottomAction: isClosed
            ? ElevatedButton.icon(
                onPressed: () => _showRatingDialog(context, c),
                icon: const Icon(Icons.star),
                label: const Text('Rate Lawyer & Experience'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[600],
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))),
                ),
              )
            : null,
      );
    }
    
    // Fallback for cases that are not yet officially registered
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
                    c.title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    c.status,
                    style: GoogleFonts.inter(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.gavel, 'Case No: ${c.caseNumber.isNotEmpty ? c.caseNumber : 'Unassigned'}'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showCaseUpdates(context, c),
              icon: const Icon(Icons.history),
              label: const Text('View Timeline'),
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
            )
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
                    subtitle: Text('${u.description}\n${u.createdAt.toString().substring(0, 16)}', style: GoogleFonts.inter(fontSize: 12)),
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
                      
                      // Check if lawyer belongs to an office
                      final lawyerData = await Supabase.instance.client.from('profiles').select('office_id').eq('id', c.lawyerId).maybeSingle();
                      String? officeId = lawyerData?['office_id'];

                      // Insert review
                      await Supabase.instance.client.from('reviews').insert({
                        'case_id': c.id,
                        'citizen_id': user.id,
                        'lawyer_id': c.lawyerId,
                        'office_id': officeId,
                        'rating': rating,
                        'review_text': textController.text.trim(),
                      });

                      // Update Lawyer Profile Rating (Approximation)
                      // A production app would use an SQL function/trigger to safely recalculate this.
                      // For now, we increment rating_count and adjust rating simply.
                      final currentLawyer = await Supabase.instance.client.from('profiles').select('rating, rating_count').eq('id', c.lawyerId).maybeSingle();
                      if (currentLawyer != null) {
                        int count = (currentLawyer['rating_count'] ?? 0) + 1;
                        double oldRating = (currentLawyer['rating'] ?? 0).toDouble();
                        double newRating = ((oldRating * (count - 1)) + rating) / count;
                        
                        await Supabase.instance.client.from('profiles').update({
                          'rating': newRating,
                          'rating_count': count
                        }).eq('id', c.lawyerId);
                      }

                      // Update Office Rating if applicable
                      if (officeId != null) {
                        final currentOffice = await Supabase.instance.client.from('lawyer_offices').select('rating, rating_count').eq('id', officeId).maybeSingle();
                        if (currentOffice != null) {
                          int count = (currentOffice['rating_count'] ?? 0) + 1;
                          double oldRating = (currentOffice['rating'] ?? 0).toDouble();
                          double newRating = ((oldRating * (count - 1)) + rating) / count;
                          
                          await Supabase.instance.client.from('lawyer_offices').update({
                            'rating': newRating,
                            'rating_count': count
                          }).eq('id', officeId);
                        }
                      }

                      Navigator.pop(ctx);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted successfully!')));
                    } catch (e) {
                      debugPrint('Error submitting review: $e');
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
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.inter(
            color: Colors.grey[700],
            fontSize: 14,
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
        Column(
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
      ],
    );
  }
}
