import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../controllers/request_provider.dart';
import '../../../models/consultation_request.dart';
import '../../../models/lawyer_office.dart';
import 'lawyer_public_profile_screen.dart';

class OfficeDetailsScreen extends StatelessWidget {
  final LawyerOffice office;
  final VoidCallback? onBookingSuccess;

  const OfficeDetailsScreen({Key? key, required this.office, this.onBookingSuccess}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                office.name,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 3.0,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    office.imageUrl,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: Theme.of(context).primaryColor,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${office.rating} Office Rating',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(context, Icons.location_on, office.address),
                  const SizedBox(height: 12),
                  _buildInfoRow(context, Icons.phone, office.contactNumber),
                  const SizedBox(height: 24),
                  Divider(color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Lawyers in this Office',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final lawyer = office.lawyers[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: _buildLawyerCard(context, lawyer),
                );
              },
              childCount: office.lawyers.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLawyerCard(BuildContext context, OfficeLawyer lawyer) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(lawyer.imageUrl),
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lawyer.name,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${lawyer.rating} (${lawyer.reviewsCount} reviews)',
                            style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Focusing Cases:',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: lawyer.focusingCases.map((caseFocus) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              caseFocus,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final shouldBook = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LawyerPublicProfileScreen(
                        lawyer: {
                          'username': lawyer.name,
                          'role': 'Lawyer',
                        },
                      ),
                    ),
                  );
                  
                  if (shouldBook == true) {
                    _checkAndShowBookingDialog(context, lawyer.name);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('View Profile & Book'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _checkAndShowBookingDialog(BuildContext context, String lawyerName) {
    final requestProvider = Provider.of<RequestProvider>(context, listen: false);

    final alreadyBooked = requestProvider.requests.any((req) =>
        req.lawyerName.toLowerCase() == lawyerName.toLowerCase() && 
        req.status != 'Rejected' && 
        req.status != 'Closed' && 
        req.status != 'Completed' && 
        req.status != 'Resolved');

    if (alreadyBooked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already sent a request to this lawyer.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _showBookingDialog(context, lawyerName);
  }

  void _showBookingDialog(BuildContext context, String lawyerName) {
    final issueController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Request Consultation with $lawyerName', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: issueController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Briefly describe your legal issue...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                  onPressed: () {
                    if (issueController.text.trim().isEmpty) return;

                    final alreadyBooked = Provider.of<RequestProvider>(context, listen: false)
                        .requests.any((req) => req.lawyerName.toLowerCase() == lawyerName.toLowerCase() && 
                                              req.status != 'Rejected' && 
                                              req.status != 'Closed' && 
                                              req.status != 'Completed' && 
                                              req.status != 'Resolved');
                    
                    if (alreadyBooked) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already sent a request to this lawyer.'), backgroundColor: Colors.orange));
                      return;
                    }

                    final user = Supabase.instance.client.auth.currentUser;
                    final citizenUsername = user?.userMetadata?['username'] ?? 'Citizen';

                    final request = ConsultationRequest(
                      id: Uuid().v4(),
                      citizenName: citizenUsername,
                      lawyerName: lawyerName,
                      issueDescription: issueController.text.trim(),
                      requestedAt: DateTime.now(),
                    );

                    Provider.of<RequestProvider>(context, listen: false).addRequest(request);
                    
                    Navigator.pop(context); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request Sent Successfully!'), backgroundColor: Colors.green));
                    
                    if (onBookingSuccess != null) {
                      Navigator.pop(context); // Pop OfficeDetailsScreen
                      onBookingSuccess!();
                    }
                  },
                  child: const Text('Send Request'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
