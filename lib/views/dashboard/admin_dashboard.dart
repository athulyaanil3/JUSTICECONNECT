import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:justice_connect/views/auth/unified_auth_screen.dart';

import 'admin_tabs/admin_overview_tab.dart';
import 'admin_tabs/lawyer_management_tab.dart';
import 'admin_tabs/complaint_management_tab.dart';
import 'admin_tabs/office_management_tab.dart';
import 'admin_tabs/admin_credentials_tab.dart';
import 'admin_tabs/admin_notifications_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _supabase = Supabase.instance.client;
  int _selectedIndex = 0;
  final List<String> _titles = [
    'JusticeConnect Admin',
    'Lawyer Management',
    'Complaint Management',
    'Office Management',
    'Credentials & Passwords',
  ];

  late final List<Widget> _tabs = [
    AdminOverviewTab(
      onNavigateToTab: (index) {
        setState(() => _selectedIndex = index);
      },
    ),
    const LawyerManagementTab(),
    const ComplaintManagementTab(),
    const OfficeManagementTab(),
    const AdminCredentialsTab(),
  ];

  @override
  void initState() {
    super.initState();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // Close drawer
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Logout from Console', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to end your administrator session?', style: GoogleFonts.inter(color: Colors.grey[700])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey[600], fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('isAdminLoggedIn');
              await _supabase.auth.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const UnifiedAuthScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentAdminEmail = _supabase.auth.currentUser?.email ?? 'admin@justiceconnect.gov';

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvoked: (didPop) {
        if (didPop) return;
        setState(() {
          _selectedIndex = 0;
        });
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          title: Text(
            _titles[_selectedIndex],
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: const Color(0xFF0D256C)),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0D256C),
          elevation: 0.5,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Color(0xFF0D256C)),
              tooltip: 'Notifications',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminNotificationsScreen()));
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              tooltip: 'Logout',
              onPressed: _showLogoutDialog,
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: Colors.white,
          child: Column(
            children: [
              // Sleek Admin Drawer Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 54, bottom: 24, left: 20, right: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D256C), Color(0xFF1A3B99)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded, size: 36, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Admin Console',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentAdminEmail,
                      style: GoogleFonts.inter(color: Colors.white.withOpacity(0.8), fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Drawer Navigation Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 4),
                      child: Text(
                        'MAIN NAVIGATION',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 0.8),
                      ),
                    ),
                    _buildDrawerItem(
                      icon: Icons.dashboard_outlined,
                      activeIcon: Icons.dashboard_rounded,
                      text: 'Overview',
                      index: 0,
                    ),
                    _buildDrawerItem(
                      icon: Icons.gavel_outlined,
                      activeIcon: Icons.gavel_rounded,
                      text: 'Lawyer Management',
                      index: 1,
                    ),
                    _buildDrawerItem(
                      icon: Icons.report_problem_outlined,
                      activeIcon: Icons.report_problem_rounded,
                      text: 'Complaint Management',
                      index: 2,
                    ),
                    _buildDrawerItem(
                      icon: Icons.business_outlined,
                      activeIcon: Icons.business_rounded,
                      text: 'Office Management',
                      index: 3,
                    ),
                    _buildDrawerItem(
                      icon: Icons.vpn_key_outlined,
                      activeIcon: Icons.vpn_key_rounded,
                      text: 'Credentials & Passwords',
                      index: 4,
                    ),
                  ],
                ),
              ),

              // Bottom Status & Logout Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Systems Online',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: _showLogoutDialog,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded, size: 16, color: Colors.red[600]),
                            const SizedBox(width: 4),
                            Text('Logout', style: GoogleFonts.inter(fontSize: 12, color: Colors.red[600], fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: _tabs[_selectedIndex],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required IconData activeIcon,
    required String text,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF0D256C).withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        dense: true,
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? const Color(0xFF0D256C) : Colors.grey[700],
          size: 22,
        ),
        title: Text(
          text,
          style: GoogleFonts.inter(
            color: isSelected ? const Color(0xFF0D256C) : Colors.grey[800],
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF0D256C),
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () => _onItemTapped(index),
      ),
    );
  }
}


