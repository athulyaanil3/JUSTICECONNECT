import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminOverviewTab extends StatefulWidget {
  const AdminOverviewTab({Key? key}) : super(key: key);

  @override
  _AdminOverviewTabState createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  int _totalUsers = 0;
  int _totalLawyers = 0;
  int _pendingVerifications = 0;

  @override
  void initState() {
    super.initState();
    _fetchMetrics();
  }

  Future<void> _fetchMetrics() async {
    setState(() => _isLoading = true);
    try {
      // Fetch Total Users
      final allProfiles = await _supabase.from('profiles').select();
      _totalUsers = allProfiles.length;

      // Fetch Total Lawyers
      final lawyers = await _supabase.from('profiles').select().eq('role', 'Lawyer');
      _totalLawyers = lawyers.length;

      // Fetch Pending Verifications (Lawyers where is_verified is false)
      final pending = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'Lawyer')
          .eq('is_verified', false);
      _pendingVerifications = pending.length;

    } catch (e) {
      debugPrint('Error fetching metrics: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _fetchMetrics,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 40, left: 24, right: 24, bottom: 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D256C), Color(0xFF1A3B99)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Console',
                    style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage users, lawyers, and platform settings',
                    style: GoogleFonts.inter(fontSize: 15, color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Overview',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
                  ),
                  const SizedBox(height: 16),
          _buildMetricCard(
            context,
            title: 'Total Users',
            value: _totalUsers.toString(),
            icon: Icons.people,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildMetricCard(
            context,
            title: 'Total Lawyers',
            value: _totalLawyers.toString(),
            icon: Icons.gavel,
            color: Colors.purple,
          ),
          const SizedBox(height: 16),
          _buildMetricCard(
            context,
            title: 'Pending Verifications',
            value: _pendingVerifications.toString(),
            icon: Icons.pending_actions,
            color: Colors.orange,
          ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.1), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.6), color],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 15, color: Colors.grey[600], fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
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
