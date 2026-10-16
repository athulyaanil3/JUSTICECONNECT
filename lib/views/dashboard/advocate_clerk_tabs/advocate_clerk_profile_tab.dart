import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:justice_connect/views/auth/unified_auth_screen.dart';
import '../../shared/submit_complaint_screen.dart';

class AdvocateClerkProfileTab extends StatefulWidget {
  const AdvocateClerkProfileTab({Key? key}) : super(key: key);

  @override
  _AdvocateClerkProfileTabState createState() => _AdvocateClerkProfileTabState();
}

class _AdvocateClerkProfileTabState extends State<AdvocateClerkProfileTab> {
  final _supabase = Supabase.instance.client;
  String _clerkName = 'Advocate Clerk';
  String _courtName = 'Unknown Court';
  String? _lawyerName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final clerkData = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();
        if (clerkData != null) {
          _clerkName = clerkData['username'] ?? 'Advocate Clerk';
          _courtName = clerkData['court_id'] ?? 'Unknown Court';

          if (clerkData['associated_lawyer_id'] != null) {
            final lawyerData = await _supabase.from('profiles').select('username').eq('id', clerkData['associated_lawyer_id']).maybeSingle();
            if (lawyerData != null) {
              _lawyerName = lawyerData['username'];
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching clerk profile: $e');
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log Out', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out of your clerk account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _supabase.auth.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const UnifiedAuthScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F9FC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final userEmail = _supabase.auth.currentUser?.email ?? 'Unknown Email';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: const Color(0xFF0D256C)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D256C),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_outlined, color: Colors.blue),
            tooltip: 'Support & Grievances',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SubmitComplaintScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProfileData,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Profile Header Card (unified design with citizen and lawyer)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: const Color(0xFF0D256C).withOpacity(0.1),
                    child: Text(
                      _clerkName.isNotEmpty ? _clerkName[0].toUpperCase() : 'C',
                      style: GoogleFonts.outfit(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0D256C),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _clerkName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D256C).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge_outlined, size: 16, color: Color(0xFF0D256C)),
                        const SizedBox(width: 6),
                        Text(
                          'Advocate Clerk • $_courtName',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF0D256C),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userEmail,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_lawyerName != null) ...[
              Text(
                'Supervising Practice',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF0D256C),
                    child: Icon(Icons.gavel, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    'Adv. $_lawyerName',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
                  ),
                  subtitle: Text(
                    'Supervising Advocate',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            Text(
              'Support & Assistance',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade50,
                  child: const Icon(Icons.report_problem_outlined, color: Colors.red),
                ),
                title: Text(
                  'Report Issue / Grievance',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                subtitle: Text(
                  'Directly inform admin about app issues or office grievances',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SubmitComplaintScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
