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
          backgroundColor: Colors.grey[50],
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
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overview',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
                      ),
                      const SizedBox(height: 16),
                      // Statistics Grid
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildStatCard(
                            context, 
                            'Total Clients', 
                            totalClients.toString(), 
                            Icons.people, 
                            Colors.blue,
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
                            Icons.folder, 
                            Colors.orange,
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
                            Icons.calendar_today, 
                            Colors.green,
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
                            Icons.assignment, 
                            Colors.red,
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
                      
                      Text(
                        'Today\'s Hearings (Causelist)',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0D256C),
                        ),
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

                      const SizedBox(height: 32),
                      
                      Text(
                        'Today\'s Appointments',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0D256C),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (todayAppointments.isEmpty)
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text('No appointments scheduled for today.', style: GoogleFonts.inter(color: Colors.grey)),
                          ),
                        )
                      else
                        ...todayAppointments.map((a) => _buildAppointmentCard(
                          context, 
                          clientName: a.citizenName, 
                          time: DateFormat('hh:mm a').format(a.requestedAt), 
                          type: 'Consultation'
                        )).toList(),
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
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF0D256C),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
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
                  'Welcome Adv. $role',
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'Here\'s what\'s happening with your\npractice today.',
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          Stack(
            children: [
              InkWell(
                onTap: onNotifTap,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber, width: 1.5),
                  ),
                  child: const Icon(Icons.notifications_active_outlined, color: Colors.amber, size: 28),
                ),
              ),
              if (hasUnread)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
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

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, MaterialColor color, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color.shade700, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
            ),
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(BuildContext context, {required String clientName, required String time, required String type}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(Icons.person, color: Theme.of(context).primaryColor),
        ),
        title: Text(clientName, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        subtitle: Text('$type • $time', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
        trailing: IconButton(
          icon: const Icon(Icons.video_call),
          color: Colors.green,
          onPressed: () { 
            // Video call implementation
          },
        ),
      ),
    );
  }
}
