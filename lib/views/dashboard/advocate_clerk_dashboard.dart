import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../controllers/advocate_clerk_provider.dart';
import 'advocate_clerk_tabs/advocate_clerk_home_tab.dart';
import 'advocate_clerk_tabs/advocate_clerk_hearings_tab.dart';
import 'advocate_clerk_tabs/advocate_clerk_filings_tab.dart';
import 'advocate_clerk_tabs/advocate_clerk_cases_tab.dart';
import 'advocate_clerk_tabs/advocate_clerk_profile_tab.dart';
import 'shared/causelist_tab.dart';

class AdvocateClerkDashboard extends StatefulWidget {
  const AdvocateClerkDashboard({super.key});

  @override
  State<AdvocateClerkDashboard> createState() => _AdvocateClerkDashboardState();
}

class _AdvocateClerkDashboardState extends State<AdvocateClerkDashboard> {
  int _currentIndex = 0;

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
    _updateSecurity();
  }

  late final List<Widget> _tabs = [
    AdvocateClerkHomeTab(
      onNavigateToFilings: () => _switchTab(1),
      onNavigateToCases: () => _switchTab(2),
      onNavigateToCauselist: () => _switchTab(3),
      onNavigateToHearings: () => _switchTab(4),
      onNavigateToProfile: () => _switchTab(5),
    ),
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

  Future<void> _updateSecurity() async {
    // Security placeholder if needed for specific tabs
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _switchTab(0);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: _tabs[_currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _switchTab,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF0D256C),
            unselectedItemColor: Colors.grey.shade400,
            selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 11),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 11),
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard, color: Color(0xFF0D256C)),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.folder_outlined),
                activeIcon: Icon(Icons.folder, color: Color(0xFF0D256C)),
                label: 'Filings',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.gavel_outlined),
                activeIcon: Icon(Icons.gavel, color: Color(0xFF0D256C)),
                label: 'Cases',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today_outlined),
                activeIcon: Icon(Icons.calendar_today, color: Color(0xFF0D256C)),
                label: 'Schedule',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.event_note_outlined),
                activeIcon: Icon(Icons.event_note, color: Color(0xFF0D256C)),
                label: 'Hearings',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person, color: Color(0xFF0D256C)),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
