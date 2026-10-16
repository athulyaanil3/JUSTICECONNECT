import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth/unified_auth_screen.dart';
import 'dashboard/admin_dashboard.dart';
import 'dashboard/citizen_dashboard.dart';
import 'dashboard/lawyer_dashboard.dart';
import 'dashboard/advocate_clerk_dashboard.dart';
import 'auth/pending_approval_screen.dart';
import 'auth/lawyer_verification_screen.dart';
import 'auth/advocate_clerk_verification_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.forward();

    Timer(const Duration(seconds: 3), () async {
      final prefs = await SharedPreferences.getInstance();
      final isAdminLoggedIn = prefs.getBool('isAdminLoggedIn') ?? false;

      if (isAdminLoggedIn) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AdminDashboard()),
            (route) => false,
          );
        }
        return;
      }

      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        try {
          final data = await Supabase.instance.client
              .from('profiles')
              .select('role, is_verified')
              .eq('id', session.user.id)
              .maybeSingle();
              
          if (!mounted) return;
          
          if (data != null) {
            final role = data['role']?.toString();
            final isVerified = data['is_verified'];
            
            if (role == 'Administrator') {
              await prefs.setBool('isAdminLoggedIn', true);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AdminDashboard()),
                (route) => false,
              );
              return;
            } else if (role == 'Citizen') {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const CitizenDashboard()),
                (route) => false,
              );
              return;
            } else if (role == 'Lawyer') {
              if (isVerified == true) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LawyerDashboard()),
                  (route) => false,
                );
              } else {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => PendingApprovalScreen(isRejected: isVerified == false, role: role)),
                  (route) => false,
                );
              }
              return;
            } else if (role == 'Advocate Clerk') {
              if (isVerified == true) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AdvocateClerkDashboard()),
                  (route) => false,
                );
              } else {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => PendingApprovalScreen(isRejected: isVerified == false, role: role)),
                  (route) => false,
                );
              }
              return;
            }
          } else {
            // User has an active session but no profile row yet
            final metaRole = session.user.userMetadata?['role'];
            if (metaRole == 'Lawyer') {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LawyerVerificationScreen()),
                (route) => false,
              );
              return;
            } else if (metaRole == 'Advocate Clerk') {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AdvocateClerkVerificationScreen()),
                (route) => false,
              );
              return;
            } else {
              // Citizen or generic
              try {
                await Supabase.instance.client.from('profiles').insert({
                  'id': session.user.id,
                  'username': session.user.userMetadata?['username'] ?? session.user.email?.split('@')[0] ?? 'Citizen',
                  'email': session.user.email ?? '',
                  'role': 'Citizen',
                  'is_verified': true,
                });
              } catch (_) {}
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const CitizenDashboard()),
                (route) => false,
              );
              return;
            }
          }
        } catch (e) {
          debugPrint('Error getting user profile for auto-login: $e');
        }
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const UnifiedAuthScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset(
            'assets/images/bg_justice.jpg',
            fit: BoxFit.cover,
            color: Colors.black.withValues(alpha: 0.4),
            colorBlendMode: BlendMode.darken,
          ),
          
          // App Logo and Name
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.balance, // Scale of justice icon
                    size: 80,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'JusticeConnect',
                    style: GoogleFonts.outfit(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI-Powered Legal Assistance',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
