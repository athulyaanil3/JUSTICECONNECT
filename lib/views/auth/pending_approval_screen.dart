import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:justice_connect/views/auth/unified_auth_screen.dart';
import '../dashboard/lawyer_dashboard.dart';
import '../dashboard/advocate_clerk_dashboard.dart';
import 'lawyer_verification_screen.dart' as justice_connect_lawyer;
import 'advocate_clerk_verification_screen.dart' as justice_connect_clerk;

class PendingApprovalScreen extends StatefulWidget {
  final bool isRejected;
  final String? role;
  
  const PendingApprovalScreen({Key? key, this.isRejected = false, this.role}) : super(key: key);

  @override
  _PendingApprovalScreenState createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  late bool _isRejected;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isRejected = widget.isRejected;
  }

  void _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const UnifiedAuthScreen()),
        (route) => false,
      );
    }
  }

  void _checkStatus(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('is_verified, role')
          .eq('id', user.id)
          .single();

      final isVerified = data['is_verified'];
      final role = data['role'];

      if (isVerified == true) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account verified! Welcome to your dashboard.'), backgroundColor: Colors.green),
          );
          if (role == 'Lawyer') {
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LawyerDashboard()), (route) => false);
          } else if (role == 'Advocate Clerk') {
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AdvocateClerkDashboard()), (route) => false);
          } else {
             _logout(context);
          }
        }
      } else if (isVerified == false) {
        setState(() {
          _isRejected = true;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your account has been reviewed and rejected.'), backgroundColor: Colors.red),
          );
        }
      } else {
        setState(() {
          _isRejected = false;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your account is still pending verification.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking status: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking status: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon Container
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _isRejected ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _isRejected ? Colors.red.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRejected ? Icons.gavel : Icons.hourglass_top,
                      size: 80,
                      color: _isRejected ? Colors.red : Colors.orange[600],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Main Content Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _isRejected ? 'Application Rejected' : 'Verification Pending',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0D256C),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Text(
                            _isRejected 
                              ? 'Your application has been reviewed and unfortunately rejected by the administrator. Please contact support for more information or try registering again.'
                              : 'Your account and uploaded documents are currently under review by our administration team. This standard verification process usually takes 24-48 hours.',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: Colors.grey[700],
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        if (_isRejected) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (widget.role == 'Lawyer') {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const justice_connect_lawyer.LawyerVerificationScreen()));
                                } else if (widget.role == 'Advocate Clerk') {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const justice_connect_clerk.AdvocateClerkVerificationScreen()));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unknown role to resubmit.')));
                                }
                              },
                              icon: const Icon(Icons.refresh, color: Colors.white),
                              label: Text(
                                'Resubmit Application',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Logout Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : () => _logout(context),
                            icon: const Icon(Icons.logout, color: Colors.white),
                            label: Text(
                              'Sign Out',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
