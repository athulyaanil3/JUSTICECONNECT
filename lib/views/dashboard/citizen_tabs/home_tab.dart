import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../controllers/notification_provider.dart';
import '../../../controllers/request_provider.dart';
import '../../widgets/dashboard_header.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class HomeTab extends StatelessWidget {
  final VoidCallback? onNavigateToSearch;
  final VoidCallback? onNavigateToAI;

  const HomeTab({
    Key? key,
    this.onNavigateToSearch,
    this.onNavigateToAI,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Fetch actual username from Supabase
    final user = Supabase.instance.client.auth.currentUser;
    final username = user?.userMetadata?['username'] ?? 'Citizen';

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Consumer<NotificationProvider>(
                  builder: (context, notifProvider, child) {
                    return _buildDashboardHeader(context, username, notifProvider);
                  }
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Actions
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              context,
                              title: 'Ask AI',
                              icon: Icons.smart_toy,
                              color: Theme.of(context).colorScheme.secondary,
                              onTap: () {
                                if (onNavigateToAI != null) {
                                  onNavigateToAI!();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildActionCard(
                              context,
                              title: 'Find Lawyer',
                              icon: Icons.search,
                              color: Colors.blue,
                              onTap: () {
                                if (onNavigateToSearch != null) {
                                  onNavigateToSearch!();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      // Consultation Requests Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Consultation Requests',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0D256C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Consumer<RequestProvider>(
                        builder: (context, requestProvider, child) {
                          final requests = requestProvider.requests.where((r) => r.status != 'Closed' && r.status != 'Resolved').take(3).toList();
                          
                          if (requests.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Text(
                                  'No active requests found.',
                                  style: GoogleFonts.inter(color: Colors.grey, fontSize: 14),
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: requests.map((req) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: _buildCaseCard(
                                  context,
                                  caseName: 'Request to ${req.lawyerName}',
                                  status: req.status,
                                  date: 'Requested on: ${req.requestedAt.toLocal().toString().split(' ')[0]}',
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ), // End of Padding
              ],
            ), // End of outer Column
          ), // End of SingleChildScrollView
        ); // End of Scaffold
      }

  Widget _buildActionCard(BuildContext context, {required String title, required IconData icon, required Color color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.8), color],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaseCard(BuildContext context, {required String caseName, required String status, required String date}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D256C).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.folder_open, color: Color(0xFF0D256C), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caseName,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: const Color(0xFF0D256C),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.inter(
                            color: Colors.blue[700],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            date.replaceAll('Requested on: ', ''),
                            style: GoogleFonts.inter(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildDashboardHeader(BuildContext context, String username, NotificationProvider notifProvider) {
    return DashboardHeader(
      title: 'Welcome back,\n$username!',
      subtitle: 'Here is your personalized legal overview.',
      unreadNotifications: notifProvider.unreadCount,
      onNotificationTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      },
      onProfileTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
      },
    );
  }
}
