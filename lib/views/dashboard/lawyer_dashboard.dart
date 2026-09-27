import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
// removed flutter_windowmanager import

import '../../../controllers/request_provider.dart';
import '../../../controllers/notification_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lawyer_tabs/lawyer_home_tab.dart';
import 'lawyer_tabs/client_management_tab.dart';
import 'lawyer_tabs/case_management_tab.dart';
import 'lawyer_tabs/appointment_tab.dart';
import 'messages_tab.dart';
import 'lawyer_tabs/lawyer_profile_tab.dart';
import 'shared/causelist_tab.dart';

class LawyerDashboard extends StatefulWidget {
  const LawyerDashboard({Key? key}) : super(key: key);

  @override
  _LawyerDashboardState createState() => _LawyerDashboardState();
}

class _LawyerDashboardState extends State<LawyerDashboard> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _updateSecurity();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RequestProvider>(context, listen: false).fetchRequests();
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // NotificationProvider usually uses the username as the targetUser
        Supabase.instance.client.from('profiles').select('username').eq('id', user.id).maybeSingle().then((profile) {
          if (profile != null && profile['username'] != null) {
            Provider.of<NotificationProvider>(context, listen: false).fetchNotifications(profile['username']);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    // FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    super.dispose();
  }

  Future<void> _updateSecurity() async {
    // Secure ClientManagementTab (1), CaseManagementTab (2), MessagesTab (4)
    if (_currentIndex == 1 || _currentIndex == 2 || _currentIndex == 4) {
      // await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } else {
      // await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    }
  }

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
    _updateSecurity();
  }

  late final List<Widget> _tabs = [
    LawyerHomeTab(onNavigateToClients: () => _switchTab(1)),
    const ClientManagementTab(),
    const CaseManagementTab(),
    const CauselistTab(role: 'Lawyer'),
    const AppointmentTab(),
    const MessagesTab(),
    const LawyerProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            _updateSecurity();
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Clients',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined),
              activeIcon: Icon(Icons.folder),
              label: 'Cases',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              activeIcon: Icon(Icons.list_alt),
              label: 'Causelist',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Appointments',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}


