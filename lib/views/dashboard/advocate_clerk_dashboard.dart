import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
// removed flutter_windowmanager import

import '../../controllers/advocate_clerk_provider.dart';
import 'advocate_clerk_tabs/advocate_clerk_home_tab.dart';
import 'advocate_clerk_tabs/advocate_clerk_hearings_tab.dart';
import 'advocate_clerk_tabs/advocate_clerk_filings_tab.dart';
import 'advocate_clerk_tabs/advocate_clerk_cases_tab.dart';
import 'advocate_clerk_tabs/advocate_clerk_profile_tab.dart';
import 'advocate_clerk_tabs/advocate_clerk_notifications_screen.dart';
import 'shared/causelist_tab.dart';

class AdvocateClerkDashboard extends StatefulWidget {
  const AdvocateClerkDashboard({Key? key}) : super(key: key);

  @override
  _AdvocateClerkDashboardState createState() => _AdvocateClerkDashboardState();
}

class _AdvocateClerkDashboardState extends State<AdvocateClerkDashboard> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const AdvocateClerkHomeTab(),
    const AdvocateClerkFilingsTab(),
    const AdvocateClerkCasesTab(),
    const CauselistTab(role: 'Advocate Clerk'),
    const AdvocateClerkHearingsTab(),
    const AdvocateClerkProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _updateSecurity();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdvocateClerkProvider>(context, listen: false).fetchAllData();
    });
  }

  @override
  void dispose() {
    // FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    super.dispose();
  }

  Future<void> _updateSecurity() async {
    // Secure FilingsTab (1), CasesTab (2), Causelist (3), HearingsTab (4)
    if (_currentIndex >= 1 && _currentIndex <= 4) {
      // await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } else {
      // await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Clerk Console',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black87),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvocateClerkNotificationsScreen()));
            },
          ),
          // Profile handles logout now
        ],
      ),
      body: _tabs[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
          unselectedItemColor: Colors.grey[400],
          selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined),
              activeIcon: Icon(Icons.folder),
              label: 'Filings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.gavel_outlined),
              activeIcon: Icon(Icons.gavel),
              label: 'Cases',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
              activeIcon: Icon(Icons.list_alt),
              label: 'Causelist',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Hearings',
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


