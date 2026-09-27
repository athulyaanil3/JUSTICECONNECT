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
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Dashboard Overview',
            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
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
    );
  }

  Widget _buildMetricCard(BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold),
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
