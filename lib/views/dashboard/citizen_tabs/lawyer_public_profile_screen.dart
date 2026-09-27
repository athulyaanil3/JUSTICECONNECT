import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LawyerPublicProfileScreen extends StatelessWidget {
  final Map<String, dynamic> lawyer;

  const LawyerPublicProfileScreen({Key? key, required this.lawyer}) : super(key: key);

  List<Map<String, dynamic>> _getAchievements() {
    final achievements = lawyer['achievements'];
    List<Map<String, dynamic>> parsedAchievements = [];
    
    if (achievements != null && achievements.toString().isNotEmpty) {
      try {
        if (achievements is String) {
          parsedAchievements = List<Map<String, dynamic>>.from(jsonDecode(achievements));
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
          'description': 'Representing clients in high-stakes corporate and civil litigation. Successfully resolved over 100+ complex disputes.'
        },
        {
          'title': 'Legal Consultant',
          'year': '2014 - 2018',
          'description': 'Provided comprehensive legal counsel on compliance, dispute resolution, and contract negotiations for major tech firms.'
        }
      ];
    }
    
    return parsedAchievements;
  }

  @override
  Widget build(BuildContext context) {
    final name = lawyer['username'] ?? 'Adv. Sharma';
    final spec = lawyer['specialization']?.toString().isNotEmpty == true ? lawyer['specialization'] : 'Corporate Law & Civil Litigation';
    
    String rawExp = lawyer['experience']?.toString() ?? '0';
    final exp = (rawExp == '0' || rawExp.isEmpty) ? '10' : rawExp;
    
    final bio = lawyer['bio']?.toString().isNotEmpty == true 
        ? lawyer['bio'] 
        : 'Dedicated and results-driven legal professional with extensive experience in Corporate Law and Civil Litigation. Proven track record of representing clients in high-stakes negotiations and courtroom proceedings.';
    
    final achievements = _getAchievements();
    
    // Generate pseudo-random stats based on lawyer name so it looks unique per lawyer
    final int nameHash = name.hashCode;
    final int baseRating = (nameHash % 10) + 40; // 4.0 to 4.9
    final double displayRating = baseRating / 10.0;
    final int consultations = (nameHash % 200) + 50;
    final int connections = (nameHash % 500) + 150;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2EF), // LinkedIn background color
      appBar: AppBar(
        title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18)),
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
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 8),
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
                            image: (lawyer['cover_url'] != null && lawyer['cover_url'].toString().isNotEmpty)
                                ? NetworkImage(lawyer['cover_url'])
                                : const AssetImage('assets/images/bg_justice.jpg') as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                          color: const Color(0xFF0077b5), // Fallback LinkedIn Blue
                        ),
                      ),
                      // Profile Picture
                      Positioned(
                        top: 70,
                        left: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: (lawyer['profile_url'] != null && lawyer['profile_url'].toString().isNotEmpty)
                                ? NetworkImage(lawyer['profile_url'])
                                : null,
                            child: (lawyer['profile_url'] == null || lawyer['profile_url'].toString().isEmpty)
                                ? Icon(Icons.person, size: 60, color: Colors.grey[500])
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
                        Text(name, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text(
                          '$spec | $exp+ Years of Experience',
                          style: GoogleFonts.inter(fontSize: 15, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'JusticeConnect Verified Advocate',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber[600], size: 16),
                            const SizedBox(width: 4),
                            Text('$displayRating', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(' ($consultations+ consultations)', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14)),
                            const SizedBox(width: 16),
                            Text('•', style: GoogleFonts.inter(color: Colors.grey[600])),
                            const SizedBox(width: 16),
                            Text('$connections+ Connections', style: GoogleFonts.inter(color: const Color(0xFF0A66C2), fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context, true); // True indicates "Book Now" was pressed
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0A66C2), // LinkedIn Blue
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text('Book Consultation', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                                side: BorderSide(color: Colors.grey[400]!),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              child: Text('Message', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            // ABOUT CARD
            Container(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 12),
                  Text(
                    bio,
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.black87, height: 1.5),
                  ),
                ],
              ),
            ),
            
            // ACHIEVEMENTS / EXPERIENCE CARD
            Container(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Experience & Achievements', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 16),
                  
                  if (achievements.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No experience listed yet.', style: GoogleFonts.inter(color: Colors.grey[600])),
                    )
                  else
                      ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: achievements.length,
                      separatorBuilder: (context, index) => const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final item = achievements[index];
                        final type = item['type'] ?? 'award';
                        
                        IconData icon = Icons.emoji_events;
                        String subtitle = 'JusticeConnect Legal Hub'; // Fallback
                        
                        if (type == 'work') {
                          icon = Icons.work;
                          subtitle = item['company']?.toString().isNotEmpty == true ? item['company'] : 'Law Firm / Office';
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
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['year'] ?? '',
                                    style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  if (item['description']?.isNotEmpty == true)
                                    Text(
                                      item['description'],
                                      style: GoogleFonts.inter(color: Colors.black87, fontSize: 14, height: 1.4),
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
