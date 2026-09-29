import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// removed flutter_windowmanager import

import '../../../controllers/request_provider.dart';
import '../../../controllers/notification_provider.dart';

import 'citizen_tabs/home_tab.dart';
import 'citizen_tabs/ai_assistant_tab.dart';
import 'citizen_tabs/lawyer_search_tab.dart';
import 'citizen_tabs/case_tracking_tab.dart';
import 'messages_tab.dart';

class CitizenDashboard extends StatefulWidget {
  const CitizenDashboard({Key? key}) : super(key: key);

  @override
  _CitizenDashboardState createState() => _CitizenDashboardState();
}

class _CitizenDashboardState extends State<CitizenDashboard> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _updateSecurity();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RequestProvider>(context, listen: false).fetchRequests();
      final user = Supabase.instance.client.auth.currentUser;
      final username = user?.userMetadata?['username'] ?? 'Citizen';
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications(username);
    });
  }

  @override
  void dispose() {
    // FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    super.dispose();
  }

  Future<void> _updateSecurity() async {
    // Secure CaseTrackingTab (3) and MessagesTab (4)
    if (_currentIndex == 3 || _currentIndex == 4) {
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

  @override
  Widget build(BuildContext context) {
    final List<Widget> _tabs = [
      HomeTab(
        onNavigateToSearch: () => _switchTab(2),
        onNavigateToAI: () => _switchTab(1),
      ),
      const AIAssistantTab(),
      LawyerSearchTab(onBookingSuccess: () => _switchTab(0)),
      const CaseTrackingTab(),
      const MessagesTab(),
    ];

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvoked: (didPop) {
        if (didPop) {
          return;
        }
        _switchTab(0);
      },
      child: Scaffold(
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
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.smart_toy_outlined),
                activeIcon: Icon(Icons.smart_toy),
                label: 'AI Legal',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search_outlined),
                activeIcon: Icon(Icons.search),
                label: 'Lawyers',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.folder_outlined),
                activeIcon: Icon(Icons.gavel),
                label: 'My Cases',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat),
                label: 'Messages',
              ),
            ],
          ),
        ),
      ),
    );
  }
}


