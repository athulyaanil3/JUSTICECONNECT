import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../controllers/advocate_clerk_provider.dart';
import '../../widgets/causelist_card.dart';
import '../../widgets/dashboard_header.dart';
import 'advocate_clerk_messages_screen.dart';
import 'advocate_clerk_notifications_screen.dart';

class AdvocateClerkHomeTab extends StatefulWidget {
  final VoidCallback? onNavigateToFilings;
  final VoidCallback? onNavigateToCases;
  final VoidCallback? onNavigateToCauselist;
  final VoidCallback? onNavigateToHearings;
  final VoidCallback? onNavigateToProfile;

  const AdvocateClerkHomeTab({
    super.key,
    this.onNavigateToFilings,
    this.onNavigateToCases,
    this.onNavigateToCauselist,
    this.onNavigateToHearings,
    this.onNavigateToProfile,
  });

  @override
  State<AdvocateClerkHomeTab> createState() => _AdvocateClerkHomeTabState();
}

class _AdvocateClerkHomeTabState extends State<AdvocateClerkHomeTab> {
  String _clerkName = 'Court Clerk';

  @override
  void initState() {
    super.initState();
    _fetchProfileName();
  }

  Future<void> _fetchProfileName() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('username')
            .eq('id', user.id)
            .maybeSingle();

        if (data != null && data['username'] != null && mounted) {
          final rawName = data['username'].toString().trim();
          if (rawName.isNotEmpty) {
            setState(() {
              _clerkName = rawName;
            });
            return;
          }
        }

        // Fallback to auth metadata if profile query didn't return username
        final metaName = user.userMetadata?['username'] ?? user.userMetadata?['name'];
        if (metaName != null && metaName.toString().trim().isNotEmpty && mounted) {
          setState(() {
            _clerkName = metaName.toString().trim();
          });
        }
      } catch (e) {
        debugPrint('Error fetching clerk profile name: $e');
      }
    }
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdvocateClerkProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Scrutiny & Filing Lifecycle metrics
        final newFiles = provider.cases.where((c) => c.status == 'Submitted').length;
        final pendingVerif = provider.cases
            .where((c) => c.status == 'Under Verification' || c.status == 'Submitted')
            .length;
        final correctionReq =
            provider.cases.where((c) => c.status == 'Correction Required').length;
        final verifiedFiles = provider.cases.where((c) => c.status == 'Verified').length;

        // Court Case metrics
        final readyForCourt =
            provider.cases.where((c) => c.status == 'Ready for Court Process').length;
        final activeCases = provider.cases
            .where((c) => c.status == 'Proceeding' || c.status == 'Hearing Scheduled')
            .length;
        final closedCases =
            provider.cases.where((c) => c.status == 'Closed' || c.status == 'Dismissed').length;

        final todayCases = provider.cases.where((c) {
          if (c.nextHearingDate == null) return false;
          final now = DateTime.now();
          final localHearing = c.nextHearingDate!.toLocal();
          return localHearing.year == now.year &&
              localHearing.month == now.month &&
              localHearing.day == now.day;
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            await provider.fetchAllData();
            await _fetchProfileName();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Hero Header
                _buildHeroHeader(context),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Shortcuts Row
                      _buildQuickShortcuts(),

                      const SizedBox(height: 28),

                      // Section 1: Filing Scrutiny Pipeline
                      _buildSectionHeader(
                        title: 'Filing Scrutiny & Verification',
                        subtitle: 'Review incoming case files, petitions, and evidence',
                        actionLabel: 'View All Filings',
                        onAction: widget.onNavigateToFilings,
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.15,
                        children: [
                          _buildInteractiveStatCard(
                            title: 'New Submissions',
                            value: '$newFiles',
                            icon: Icons.note_add_outlined,
                            accentColor: const Color(0xFF1976D2),
                            bgColor: const Color(0xFFE3F2FD),
                            onTap: widget.onNavigateToFilings,
                          ),
                          _buildInteractiveStatCard(
                            title: 'Under Scrutiny',
                            value: '$pendingVerif',
                            icon: Icons.document_scanner_outlined,
                            accentColor: const Color(0xFFF57C00),
                            bgColor: const Color(0xFFFFF3E0),
                            onTap: widget.onNavigateToFilings,
                          ),
                          _buildInteractiveStatCard(
                            title: 'Correction Required',
                            value: '$correctionReq',
                            icon: Icons.warning_amber_rounded,
                            accentColor: const Color(0xFFD32F2F),
                            bgColor: const Color(0xFFFFEBEE),
                            onTap: widget.onNavigateToFilings,
                          ),
                          _buildInteractiveStatCard(
                            title: 'Verified & Cleared',
                            value: '$verifiedFiles',
                            icon: Icons.check_circle_outline,
                            accentColor: const Color(0xFF388E3C),
                            bgColor: const Color(0xFFE8F5E9),
                            onTap: widget.onNavigateToFilings,
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Section 2: Court Proceedings & Cases
                      _buildSectionHeader(
                        title: 'Court Cases & Hearings',
                        subtitle: 'Monitor courtroom readiness and daily listings',
                        actionLabel: 'View All Cases',
                        onAction: widget.onNavigateToCases,
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.15,
                        children: [
                          _buildInteractiveStatCard(
                            title: 'Ready for Court',
                            value: '$readyForCourt',
                            icon: Icons.gavel_outlined,
                            accentColor: const Color(0xFF512DA8),
                            bgColor: const Color(0xFFEDE7F6),
                            onTap: widget.onNavigateToCases,
                          ),
                          _buildInteractiveStatCard(
                            title: 'Active In-Court',
                            value: '$activeCases',
                            icon: Icons.folder_open_outlined,
                            accentColor: const Color(0xFF00796B),
                            bgColor: const Color(0xFFE0F2F1),
                            onTap: widget.onNavigateToCases,
                          ),
                          _buildInteractiveStatCard(
                            title: 'Today\'s Hearings',
                            value: '${todayCases.length}',
                            icon: Icons.calendar_today_outlined,
                            accentColor: const Color(0xFF7B1FA2),
                            bgColor: const Color(0xFFF3E5F5),
                            onTap: widget.onNavigateToHearings,
                          ),
                          _buildInteractiveStatCard(
                            title: 'Disposed / Closed',
                            value: '$closedCases',
                            icon: Icons.archive_outlined,
                            accentColor: const Color(0xFF455A64),
                            bgColor: const Color(0xFFECEFF1),
                            onTap: widget.onNavigateToCases,
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Section 3: Today's Hearing Schedule
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Today\'s Hearing Schedule',
                                  style: GoogleFonts.outfit(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0D256C),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: widget.onNavigateToCauselist,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  Text(
                                    'Full Causelist',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF0D256C),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 12,
                                    color: Color(0xFF0D256C),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (todayCases.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D256C).withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.event_available_outlined,
                                  color: Color(0xFF0D256C),
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No Hearings Scheduled Today',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0D256C),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'All court lists and courtroom sessions are up to date.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...todayCases.map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: CauselistCard(legalCase: c),
                            )),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    return DashboardHeader(
      roleTag: 'CLERK DESK',
      title: 'Welcome back,\n$_clerkName!',
      subtitle: 'Here is your courtroom and filing overview.',
      onChatTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdvocateClerkMessagesScreen(),
          ),
        );
      },
      onNotificationTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdvocateClerkNotificationsScreen(),
          ),
        );
      },
      onProfileTap: widget.onNavigateToProfile,
    );
  }

  Widget _buildQuickShortcuts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Workflow Shortcuts',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D256C),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildShortcutChip(
                label: 'Scrutinize Filings',
                icon: Icons.checklist_rtl_rounded,
                color: const Color(0xFF1976D2),
                onTap: widget.onNavigateToFilings,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildShortcutChip(
                label: 'Hearings Schedule',
                icon: Icons.schedule_outlined,
                color: const Color(0xFF7B1FA2),
                onTap: widget.onNavigateToCauselist,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildShortcutChip(
                label: 'Case Repository',
                icon: Icons.gavel,
                color: const Color(0xFF00796B),
                onTap: widget.onNavigateToCases,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildShortcutChip(
                label: 'Log Hearing Info',
                icon: Icons.event_note_outlined,
                color: const Color(0xFFE65100),
                onTap: widget.onNavigateToHearings,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShortcutChip({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required String actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0D256C),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (onAction != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                actionLabel,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0D256C),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInteractiveStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.05),
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
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D256C),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
