import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../controllers/lawyer_provider.dart';
import '../../../controllers/request_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../controllers/notification_provider.dart';
import '../notifications_screen.dart';
import '../../widgets/causelist_card.dart';

class LawyerHomeTab extends StatefulWidget {
  final VoidCallback? onNavigateToClients;
  const LawyerHomeTab({Key? key, this.onNavigateToClients}) : super(key: key);

  @override
  _LawyerHomeTabState createState() => _LawyerHomeTabState();
}

class _LawyerHomeTabState extends State<LawyerHomeTab> {
  String _advocateName = 'Advocate';

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LawyerProvider>(context, listen: false).fetchMyCases();
      Provider.of<RequestProvider>(context, listen: false).fetchRequests();
    });
  }

  Future<void> _fetchProfileData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('username')
            .eq('id', user.id)
            .maybeSingle();
        if (data != null && data['username'] != null) {
          if (mounted) {
            setState(() {
              _advocateName = data['username'];
            });
          }
        }
      } catch (e) {
        debugPrint('Error fetching profile name: $e');
      }
    }
  }

  void _showDetailsBottomSheet(BuildContext context, String title, List<Widget> items) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Expanded(
                child: items.isEmpty
                    ? Center(child: Text('No $title available.', style: GoogleFonts.inter()))
                    : ListView(children: items),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<LawyerProvider, RequestProvider, NotificationProvider>(
      builder: (context, lawyerProvider, requestProvider, notifProvider, child) {
        // Calculate Metrics
        final activeCases = lawyerProvider.myCases.where((c) => c.status != 'Closed' && c.status != 'Dismissed').toList();
        final totalClients = lawyerProvider.myCases.map((c) => c.userId).toSet().length; // unique clients
        final appointments = requestProvider.requests.where((r) => r.status == 'Accepted' || r.status == 'Confirmed').toList();
        final pendingTasks = requestProvider.requests.where((r) => r.status == 'Pending' || r.status == 'Awaiting Confirmation').toList();

        final todayCases = lawyerProvider.myCases.where((c) {
          if (c.nextHearingDate == null) return false;
          final now = DateTime.now();
          return c.nextHearingDate!.year == now.year && c.nextHearingDate!.month == now.month && c.nextHearingDate!.day == now.day;
        }).toList();
        final todayAppointments = appointments.where((a) => a.requestedAt.day == DateTime.now().day).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDashboardHeader(context, _advocateName, notifProvider, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Practice Overview',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
                      ),
                      const SizedBox(height: 16),
                      // Statistics Grid
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.1,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildStatCard(
                            context, 
                            'Total Clients', 
                            totalClients.toString(), 
                            Icons.people_outline, 
                            const Color(0xFFE3F2FD),
                            const Color(0xFF1976D2),
                            onTap: () {
                              _showDetailsBottomSheet(context, 'Total Clients', [
                                const ListTile(title: Text('Unique clients based on active & closed cases.'))
                              ]);
                            }
                          ),
                          _buildStatCard(
                            context, 
                            'Active Cases', 
                            activeCases.length.toString(), 
                            Icons.folder_open, 
                            const Color(0xFFFFF3E0),
                            const Color(0xFFF57C00),
                            onTap: () {
                              _showDetailsBottomSheet(context, 'Active Cases', 
                                activeCases.map((c) => ListTile(
                                  leading: const Icon(Icons.gavel),
                                  title: Text(c.title),
                                  subtitle: Text(c.status),
                                )).toList()
                              );
                            }
                          ),
                          _buildStatCard(
                            context, 
                            'Appointments', 
                            appointments.length.toString(), 
                            Icons.calendar_today_outlined, 
                            const Color(0xFFE8F5E9),
                            const Color(0xFF388E3C),
                            onTap: () {
                               _showDetailsBottomSheet(context, 'Appointments', 
                                appointments.map((a) => ListTile(
                                  leading: const Icon(Icons.schedule),
                                  title: Text(a.citizenName),
                                  subtitle: Text(a.status),
                                )).toList()
                              );
                            }
                          ),
                          _buildStatCard(
                            context, 
                            'Pending Tasks', 
                            pendingTasks.length.toString(), 
                            Icons.assignment_outlined, 
                            const Color(0xFFFFEBEE),
                            const Color(0xFFD32F2F),
                            onTap: () {
                              _showDetailsBottomSheet(context, 'Pending Tasks (Requests)', 
                                pendingTasks.map((t) => ListTile(
                                  leading: const Icon(Icons.pending_actions),
                                  title: Text('Request from ${t.citizenName}'),
                                  subtitle: Text(t.issueDescription, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                  onTap: () {
                                    Navigator.pop(context); // Close bottom sheet
                                    if (widget.onNavigateToClients != null) {
                                      widget.onNavigateToClients!();
                                    }
                                  },
                                )).toList()
                              );
                            }
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Today\'s Hearings',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          Text(
                            'View All',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (todayCases.isEmpty)
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                          ),
                          elevation: 0,
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.gavel_outlined, size: 48, color: Colors.grey.shade300),
                                  const SizedBox(height: 12),
                                  Text('No hearings scheduled for today.', style: GoogleFonts.inter(color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ...todayCases.map((c) => CauselistCard(legalCase: c)).toList(),

                      const SizedBox(height: 32),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Today\'s Appointments',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (todayAppointments.isEmpty)
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                          ),
                          elevation: 0,
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey.shade300),
                                  const SizedBox(height: 12),
                                  Text('No appointments scheduled for today.', style: GoogleFonts.inter(color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ...todayAppointments.map((a) => _buildAppointmentCard(
                          context, 
                          clientName: a.citizenName, 
                          time: DateFormat('hh:mm a').format(a.requestedAt), 
                          type: 'Consultation'
                        )).toList(),
                        
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildDashboardHeader(BuildContext context, String role, NotificationProvider notifProvider, VoidCallback onNotifTap) {
    final hasUnread = notifProvider.unreadCount > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome,',
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Adv. $role',
                  style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wb_sunny_outlined, color: Colors.amber, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Here\'s your practice today',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Stack(
            children: [
              InkWell(
                onTap: onNotifTap,
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                  ),
                  child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
                ),
              ),
              if (hasUnread)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF2C5364), width: 2),
                    ),
                    child: Text(
                      '${notifProvider.unreadCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color iconBgColor, Color iconColor, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(BuildContext context, {required String clientName, required String time, required String type}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.person_outline, color: Theme.of(context).primaryColor),
        ),
        title: Text(clientName, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16, color: const Color(0xFF1A1A1A))),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(time, style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Text('• $type', style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13)),
            ],
          ),
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.videocam_outlined),
            color: const Color(0xFF2E7D32),
            onPressed: () { 
              // Video call implementation
            },
          ),
        ),
      ),
    );
  }
}
