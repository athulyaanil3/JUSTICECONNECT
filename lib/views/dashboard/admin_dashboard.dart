import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:justice_connect/views/auth/unified_auth_screen.dart';

import 'admin_tabs/admin_overview_tab.dart';
import 'admin_tabs/lawyer_management_tab.dart';
import 'admin_tabs/role_management_tab.dart';
import 'admin_tabs/complaint_management_tab.dart';
import 'admin_tabs/office_management_tab.dart';
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
    'Dashboard Overview',
    'Lawyer Management',
    'Role Management',
    'Complaint Management',
    'Office Management',
  ];

  final List<Widget> _tabs = [
    const AdminOverviewTab(),
    const LawyerManagementTab(),
    const RoleManagementTab(),
    const ComplaintManagementTab(),
    const OfficeManagementTab(),
  ];

  @override
  void initState() {
    super.initState();
    _updateSecurity();
  }

  @override
  void dispose() {
    // FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    super.dispose();
  }

  Future<void> _updateSecurity() async {
    if (_selectedIndex == 0 || _selectedIndex == 1 || _selectedIndex == 3 || _selectedIndex == 4) {
      // await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } else {
      // await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _updateSecurity();
    Navigator.pop(context); // Close the drawer
  }

  void _logout() async {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_titles[_selectedIndex], style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active, color: Colors.blue),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminNotificationsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _logout,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.admin_panel_settings, size: 40, color: Colors.black),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Administrator',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              icon: Icons.dashboard,
              text: 'Overview',
              index: 0,
            ),
            _buildDrawerItem(
              icon: Icons.gavel,
              text: 'Lawyers',
              index: 1,
            ),
            _buildDrawerItem(
              icon: Icons.manage_accounts,
              text: 'Roles',
              index: 2,
            ),
            _buildDrawerItem(
              icon: Icons.report_problem,
              text: 'Complaints',
              index: 3,
            ),
            _buildDrawerItem(
              icon: Icons.business,
              text: 'Offices',
              index: 4,
            ),
          ],
        ),
      ),
      body: _tabs[_selectedIndex],
    );
  }

  Widget _buildDrawerItem({required IconData icon, required String text, required int index}) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Theme.of(context).primaryColor : Colors.grey[700]),
      title: Text(
        text,
        style: GoogleFonts.inter(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[800],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
      onTap: () => _onItemTapped(index),
    );
  }
}


