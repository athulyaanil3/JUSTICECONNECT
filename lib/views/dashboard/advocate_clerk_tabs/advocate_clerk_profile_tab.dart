import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:justice_connect/views/auth/unified_auth_screen.dart';

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

  void _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const UnifiedAuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.blue[100],
          child: const Icon(Icons.person, size: 50, color: Colors.blue),
        ),
        const SizedBox(height: 16),
        Text(
          _clerkName,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          'Advocate Clerk • $_courtName',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.blue[800], fontWeight: FontWeight.w600),
        ),
        Text(
          _supabase.auth.currentUser?.email ?? 'Unknown Email',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.grey),
        ),
        const SizedBox(height: 32),
        
        if (_lawyerName != null) ...[
          Text('Supervising Lawyer', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            color: Colors.blue[50],
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue[200]!)),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.gavel, color: Colors.white)),
              title: Text(_lawyerName!, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.blue[900])),
              subtitle: Text('justiceconnect.in/lawyer/$_lawyerName', style: GoogleFonts.inter(fontSize: 12)),
            ),
          ),
          const SizedBox(height: 32),
        ],

        ElevatedButton.icon(
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        )
      ],
    );
  }
}
