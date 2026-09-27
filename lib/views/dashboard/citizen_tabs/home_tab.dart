import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../controllers/notification_provider.dart';
import '../../../controllers/request_provider.dart';
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
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0D256C),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaseCard(BuildContext context, {required String caseName, required String status, required String date}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.folder_open, color: Colors.blue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caseName,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: const Color(0xFF0D256C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        date,
                        style: GoogleFonts.inter(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Welcome back,\n$username!',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Row(
                children: [
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: Colors.amber, size: 28),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                        },
                      ),
                      if (hasUnread)
                        Positioned(
                          right: 12,
                          top: 12,
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
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                    },
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      child: const Icon(Icons.person, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Here is your personalized legal overview.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
