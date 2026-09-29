import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../controllers/request_provider.dart';

class LawyerPublicProfileScreen extends StatefulWidget {
  final Map<String, dynamic> lawyer;

  const LawyerPublicProfileScreen({Key? key, required this.lawyer})
    : super(key: key);

  @override
  State<LawyerPublicProfileScreen> createState() =>
      _LawyerPublicProfileScreenState();
}

class _LawyerPublicProfileScreenState extends State<LawyerPublicProfileScreen> {
  double _displayRating = 0.0;
  int _reviewsCount = 0;
  bool _isLoadingRating = true;

  @override
  void initState() {
    super.initState();
    _fetchLawyerRating();
  }

  Future<void> _fetchLawyerRating() async {
    try {
      final lawyerId = widget.lawyer['id'];
      if (lawyerId == null) {
        setState(() => _isLoadingRating = false);
        return;
      }

      final response = await Supabase.instance.client
          .from('reviews')
          .select('rating')
          .eq('lawyer_id', lawyerId);

      final List<dynamic> ratings = response;
      if (ratings.isEmpty) {
        setState(() {
          _displayRating = 0.0;
          _reviewsCount = 0;
          _isLoadingRating = false;
        });
        return;
      }

      double total = 0;
      for (var row in ratings) {
        total += (row['rating'] as num).toDouble();
      }

      setState(() {
        _displayRating = total / ratings.length;
        _reviewsCount = ratings.length;
        _isLoadingRating = false;
      });
    } catch (e) {
      debugPrint('Error fetching lawyer ratings: ');
      setState(() => _isLoadingRating = false);
    }
  }

  List<Map<String, dynamic>> _getAchievements() {
    final achievements = widget.lawyer['achievements'];
    List<Map<String, dynamic>> parsedAchievements = [];

    if (achievements != null && achievements.toString().isNotEmpty) {
      try {
        if (achievements is String) {
          parsedAchievements = List<Map<String, dynamic>>.from(
            jsonDecode(achievements),
          );
        } else {
          parsedAchievements = List<Map<String, dynamic>>.from(achievements);
        }
      } catch (e) {
        debugPrint('Error parsing achievements: $e');
      }
    }

    // Add dummy data if empty
    if (parsedAchievements.isEmpty) {
      parsedAchievements = [
        {
          'title': 'Senior Advocate',
          'year': '2018 - Present',
          'description':
              'Representing clients in high-stakes corporate and civil litigation. Successfully resolved over 100+ complex disputes.',
        },
        {
          'title': 'Legal Consultant',
          'year': '2014 - 2018',
          'description':
              'Provided comprehensive legal counsel on compliance, dispute resolution, and contract negotiations for major tech firms.',
        },
      ];
    }

    return parsedAchievements;
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.lawyer['username'] ?? 'Adv. Sharma';
    final spec = widget.lawyer['specialization']?.toString().isNotEmpty == true
        ? widget.lawyer['specialization']
        : 'Corporate Law & Civil Litigation';

    final requestProvider = Provider.of<RequestProvider>(context);
    final alreadyBooked = requestProvider.requests.any(
      (req) =>
          req.lawyerName.toLowerCase() == name.toLowerCase() &&
          req.status != 'Rejected' &&
          req.status != 'Closed' &&
          req.status != 'Completed' &&
          req.status != 'Resolved',
    );

    String rawExp = widget.lawyer['experience']?.toString() ?? '0';
    final exp = (rawExp == '0' || rawExp.isEmpty) ? '10' : rawExp;

    final bio = widget.lawyer['bio']?.toString().isNotEmpty == true
        ? widget.lawyer['bio']
        : 'Dedicated and results-driven legal professional with extensive experience in Corporate Law and Civil Litigation. Proven track record of representing clients in high-stakes negotiations and courtroom proceedings.';

    final achievements = _getAchievements();

    final int nameHash = name.hashCode;
    final int consultations = (nameHash % 200) + 50;
    final int connections = (nameHash % 500) + 150;

    return Scaffold(
      backgroundColor: Colors.grey[50], // LinkedIn background color
      appBar: AppBar(
        title: Text(
          name,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // TOP CARD (Intro)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner & Profile Picture Stack
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Cover Photo Banner
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image:
                                (widget.lawyer['cover_url'] != null &&
                                    widget.lawyer['cover_url']
                                        .toString()
                                        .isNotEmpty)
                                ? NetworkImage(widget.lawyer['cover_url'])
                                : const AssetImage(
                                        'assets/images/bg_justice.jpg',
                                      )
                                      as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                          color: const Color(
                            0xFF0077b5,
                          ), // Fallback LinkedIn Blue
                        ),
                      ),
                      // Profile Picture
                      Positioned(
                        top: 70,
                        left: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            backgroundImage:
                                (widget.lawyer['profile_url'] != null &&
                                    widget.lawyer['profile_url']
                                        .toString()
                                        .isNotEmpty)
                                ? NetworkImage(widget.lawyer['profile_url'])
                                : null,
                            child:
                                (widget.lawyer['profile_url'] == null ||
                                    widget.lawyer['profile_url']
                                        .toString()
                                        .isEmpty)
                                ? Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.grey[500],
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 50), // Spacing for overlapping avatar
                  // Details
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$spec | $exp+ Years of Experience',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'JusticeConnect Verified Advocate',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              color: Colors.amber[600],
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_displayRating',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              ' ($consultations+ consultations)',
                              style: GoogleFonts.inter(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '•',
                              style: GoogleFonts.inter(color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '$connections+ Connections',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF0A66C2),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Action Buttons
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: alreadyBooked
                                ? null
                                : () {
                                    Navigator.pop(
                                      context,
                                      true,
                                    ); // True indicates "Send Request" was pressed
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: alreadyBooked
                                  ? Colors.grey[300]
                                  : Theme.of(context).primaryColor,
                              foregroundColor: alreadyBooked
                                  ? Colors.grey[600]
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: alreadyBooked ? 0 : 4,
                              shadowColor: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.4),
                            ),
                            child: Text(
                              alreadyBooked
                                  ? 'Requested'
                                  : 'Send Consultation Request',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ABOUT CARD
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    bio,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // ACHIEVEMENTS / EXPERIENCE CARD
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Experience & Achievements',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (achievements.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'No experience listed yet.',
                        style: GoogleFonts.inter(color: Colors.grey[600]),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: achievements.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final item = achievements[index];
                        final type = item['type'] ?? 'award';

                        IconData icon = Icons.emoji_events;
                        String subtitle =
                            'JusticeConnect Legal Hub'; // Fallback

                        if (type == 'work') {
                          icon = Icons.work;
                          subtitle =
                              item['company']?.toString().isNotEmpty == true
                              ? item['company']
                              : 'Law Firm / Office';
                        } else if (type == 'case') {
                          icon = Icons.gavel;
                          subtitle = 'Success Case';
                        } else {
                          subtitle = 'Award & Recognition';
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              color: Colors.grey[100],
                              child: Icon(icon, color: const Color(0xFF0A66C2)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] ?? '',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['year'] ?? '',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (item['description']?.isNotEmpty == true)
                                    Text(
                                      item['description'],
                                      style: GoogleFonts.inter(
                                        color: Colors.black87,
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
