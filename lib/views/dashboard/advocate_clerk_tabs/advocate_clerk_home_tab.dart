import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:provider/provider.dart';
import '../../../controllers/advocate_clerk_provider.dart';
import '../../widgets/causelist_card.dart';

class AdvocateClerkHomeTab extends StatelessWidget {
  const AdvocateClerkHomeTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AdvocateClerkProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final newFiles = provider.cases.where((c) => c.status == 'Submitted').length;
        final pendingVerif = provider.cases.where((c) => c.status == 'Under Verification' || c.status == 'Submitted').length;
        final correctionReq = provider.cases.where((c) => c.status == 'Correction Required').length;
        final verifiedFiles = provider.cases.where((c) => c.status == 'Verified').length;
        final readyForCourt = provider.cases.where((c) => c.status == 'Ready for Court Process').length;
        final activeCases = provider.cases.where((c) => c.status == 'Proceeding' || c.status == 'Hearing Scheduled').length;
        final closedCases = provider.cases.where((c) => c.status == 'Closed' || c.status == 'Dismissed').length;

        final todayCases = provider.cases.where((c) {
          if (c.nextHearingDate == null) return false;
          final now = DateTime.now();
          return c.nextHearingDate!.year == now.year && c.nextHearingDate!.month == now.month && c.nextHearingDate!.day == now.day;
        }).toList();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDashboardHeader(context, 'Advocate Clerk'),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overview',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
                    ),
                    const SizedBox(height: 16),
                    // Summary Cards Grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.0,
                      children: [
                        _buildStatCard(context, 'New Files', '$newFiles', Icons.note_add, Colors.blue),
                        _buildStatCard(context, 'Pending Verif.', '$pendingVerif', Icons.document_scanner, Colors.orange),
                        _buildStatCard(context, 'Correction Req.', '$correctionReq', Icons.warning, Colors.red),
                        _buildStatCard(context, 'Verified', '$verifiedFiles', Icons.check_circle, Colors.green),
                        _buildStatCard(context, 'Ready for Court', '$readyForCourt', Icons.gavel, Colors.indigo),
                        _buildStatCard(context, 'Active Cases', '$activeCases', Icons.folder_open, Colors.teal),
                        _buildStatCard(context, 'Closed Cases', '$closedCases', Icons.archive, Colors.grey),
                        _buildStatCard(context, 'Today\'s Hearings', '${todayCases.length}', Icons.calendar_today, Colors.purple),
                      ],
                    ),

                    const SizedBox(height: 32),
                    Text(
                      'Today\'s Hearings (Causelist)',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
                    ),
                    const SizedBox(height: 12),
                    
                    if (todayCases.isEmpty)
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('No hearings scheduled for today.', style: GoogleFonts.inter(color: Colors.grey)),
                        ),
                      )
                    else
                      ...todayCases.map((c) => CauselistCard(legalCase: c)).toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboardHeader(BuildContext context, String role) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 32),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,\n$role!',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Here\'s what\'s happening with your platform today.',
                  style: GoogleFonts.inter(fontSize: 15, color: Colors.white.withOpacity(0.8)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber.withOpacity(0.8), width: 2),
            ),
            child: const Icon(Icons.account_balance, color: Colors.amber, size: 36),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, MaterialColor color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.shade400, color.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
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
                child: Icon(icon, color: Colors.white, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
          ),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildJudgeScheduleItem(BuildContext context, String judge, String room, String time) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(Icons.person, color: Theme.of(context).primaryColor),
        ),
        title: Text(judge, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF0D256C))),
        subtitle: Text(room, style: GoogleFonts.inter(color: Colors.grey[600])),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            time,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
          ),
        ),
      ),
    );
  }
}
