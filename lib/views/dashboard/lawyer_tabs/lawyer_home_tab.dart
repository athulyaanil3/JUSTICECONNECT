import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../controllers/lawyer_provider.dart';
import '../../../controllers/request_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../controllers/notification_provider.dart';
import '../notifications_screen.dart';
import '../../widgets/causelist_card.dart';
import '../shared/causelist_tab.dart';
import '../../widgets/dashboard_header.dart';

class LawyerHomeTab extends StatefulWidget {
  final VoidCallback? onNavigateToClients;
  final VoidCallback? onNavigateToCases;
  final VoidCallback? onNavigateToHearings;
  final VoidCallback? onNavigateToAppointments;
  final VoidCallback? onNavigateToProfile;

  const LawyerHomeTab({
    Key? key,
    this.onNavigateToClients,
    this.onNavigateToCases,
    this.onNavigateToHearings,
    this.onNavigateToAppointments,
    this.onNavigateToProfile,
  }) : super(key: key);

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
          final localHearing = c.nextHearingDate!.toLocal();
          final now = DateTime.now();
          return localHearing.year == now.year && localHearing.month == now.month && localHearing.day == now.day;
        }).toList();
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
                              if (widget.onNavigateToClients != null) {
                                widget.onNavigateToClients!();
                              } else {
                                _showDetailsBottomSheet(context, 'Total Clients', [
                                  const ListTile(title: Text('Unique clients based on active & closed cases.'))
                                ]);
                              }
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
                              if (widget.onNavigateToCases != null) {
                                widget.onNavigateToCases!();
                              } else {
                                _showDetailsBottomSheet(context, 'Active Cases', 
                                  activeCases.map((c) => ListTile(
                                    leading: const Icon(Icons.gavel),
                                    title: Text(c.title),
                                    subtitle: Text(c.status),
                                  )).toList()
                                );
                              }
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
                              if (widget.onNavigateToAppointments != null) {
                                widget.onNavigateToAppointments!();
                              } else {
                                _showDetailsBottomSheet(context, 'Appointments', 
                                  appointments.map((a) => ListTile(
                                    leading: const Icon(Icons.schedule),
                                    title: Text(a.citizenName),
                                    subtitle: Text(a.status),
                                  )).toList()
                                );
                              }
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
                          InkWell(
                            onTap: () {
                              if (widget.onNavigateToHearings != null) {
                                widget.onNavigateToHearings!();
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => Scaffold(
                                      appBar: AppBar(
                                        title: Text('Hearings Schedule', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                      ),
                                      body: const CauselistTab(role: 'Lawyer'),
                                    ),
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'View All',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 12,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ],
                              ),
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
    return DashboardHeader(
      title: 'Welcome back,\nAdv. $role!',
      subtitle: 'Here is your legal practice overview.',
      unreadNotifications: notifProvider.unreadCount,
      onNotificationTap: onNotifTap,
      onProfileTap: widget.onNavigateToProfile,
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
}
