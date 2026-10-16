import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminOverviewTab extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const AdminOverviewTab({Key? key, this.onNavigateToTab}) : super(key: key);

  @override
  _AdminOverviewTabState createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  int _totalUsers = 0;
  int _totalLawyers = 0;
  int _totalOffices = 0;
  int _pendingVerifications = 0;
  int _pendingComplaints = 0;

  @override
  void initState() {
    super.initState();
    _fetchMetrics();
  }

  Future<void> _fetchMetrics() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Total Users
      final allProfiles = await _supabase.from('profiles').select();
      _totalUsers = allProfiles.length;

      // 2. Fetch Total Lawyers
      final lawyers = await _supabase.from('profiles').select().eq('role', 'Lawyer');
      _totalLawyers = lawyers.length;

      // 3. Fetch Total Offices
      try {
        final offices = await _supabase.from('lawyer_offices').select();
        _totalOffices = offices.length;
      } catch (_) {}

      // 4. Fetch Pending Lawyer Verifications
      try {
        final pending = await _supabase
            .from('profiles')
            .select()
            .eq('role', 'Lawyer')
            .eq('is_verified', false);
        _pendingVerifications = pending.length;
      } catch (_) {}

      // 6. Fetch Pending Complaints
      int complaintsCount = 0;
      try {
        final comp = await _supabase.from('complaints').select().neq('status', 'Resolved');
        complaintsCount += comp.length;
      } catch (_) {}

      try {
        final notifComp = await _supabase
            .from('app_notifications')
            .select()
            .eq('target_user', 'Admin')
            .ilike('title', '%Complaint%')
            .eq('is_read', false);
        if (complaintsCount == 0) {
          complaintsCount = notifComp.length;
        }
      } catch (_) {}
      _pendingComplaints = complaintsCount;

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
      color: const Color(0xFF0D256C),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Pending Alert Banner (if any pending actions exist)
            if (_pendingVerifications > 0 || _pendingComplaints > 0) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.priority_high_rounded, color: Colors.amber.shade900, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attention Required',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.amber.shade900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$_pendingVerifications pending verification(s) • $_pendingComplaints unresolved complaint(s)',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.amber.shade900),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade900,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        if (_pendingVerifications > 0) {
                          widget.onNavigateToTab?.call(1); // Go to lawyers
                        } else {
                          widget.onNavigateToTab?.call(2); // Go to complaints
                        }
                      },
                      child: Text('Review', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],

            // Metrics Section Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Platform Key Metrics',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF0D256C)),
                  tooltip: 'Refresh metrics',
                  onPressed: _fetchMetrics,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 2x2 Grid of Stat Cards matching admin modules and platform reach
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                _buildStatCard(
                  title: 'Lawyers',
                  value: _totalLawyers.toString(),
                  icon: Icons.gavel_rounded,
                  color: const Color(0xFF4338CA),
                  badge: _pendingVerifications > 0 ? '$_pendingVerifications pending' : null,
                  badgeColor: Colors.amber.shade800,
                  onTap: () => widget.onNavigateToTab?.call(1), // Lawyer Tab
                ),
                _buildStatCard(
                  title: 'Complaints',
                  value: _pendingComplaints.toString(),
                  icon: Icons.report_problem_rounded,
                  color: const Color(0xFFE11D48),
                  badge: _pendingComplaints > 0 ? 'Active' : 'Clear',
                  badgeColor: _pendingComplaints > 0 ? Colors.red : Colors.green,
                  onTap: () => widget.onNavigateToTab?.call(2), // Complaint Tab
                ),
                _buildStatCard(
                  title: 'Law Offices',
                  value: _totalOffices.toString(),
                  icon: Icons.business_rounded,
                  color: const Color(0xFF0284C7),
                  onTap: () => widget.onNavigateToTab?.call(3), // Office Tab
                ),
                _buildStatCard(
                  title: 'Platform Users',
                  value: _totalUsers.toString(),
                  icon: Icons.people_alt_rounded,
                  color: const Color(0xFF0D9488),
                  badge: 'Active',
                  badgeColor: Colors.teal.shade700,
                  onTap: () => widget.onNavigateToTab?.call(4), // Credentials Tab
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Quick Administration Shortcuts
            Text(
              'Quick Management',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
            ),
            const SizedBox(height: 12),

            _buildActionTile(
              icon: Icons.vpn_key_rounded,
              title: 'User Credentials & Passwords Vault',
              subtitle: 'Inspect encrypted AES-256 ciphers & reveal decrypted passwords',
              color: const Color(0xFF0D256C),
              onTap: () => widget.onNavigateToTab?.call(4),
            ),
            _buildActionTile(
              icon: Icons.verified_user_outlined,
              title: 'Review Lawyer Registrations',
              subtitle: 'Check Bar enrollment documents and approve accounts',
              color: const Color(0xFF4338CA),
              onTap: () => widget.onNavigateToTab?.call(1),
            ),
            _buildActionTile(
              icon: Icons.report_problem_outlined,
              title: 'Grievance & Complaint Redressal',
              subtitle: 'Inspect user reports, take action, and respond to citizens',
              color: const Color(0xFFE11D48),
              onTap: () => widget.onNavigateToTab?.call(2),
            ),
            _buildActionTile(
              icon: Icons.business_outlined,
              title: 'Law Offices & Firm Registry',
              subtitle: 'Manage verified physical office profiles and locations',
              color: const Color(0xFF0284C7),
              onTap: () => widget.onNavigateToTab?.call(3),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? badge,
    Color? badgeColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? color).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor ?? color),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
                ),
                const SizedBox(height: 1),
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF0D256C)),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
      ),
    );
  }
}
