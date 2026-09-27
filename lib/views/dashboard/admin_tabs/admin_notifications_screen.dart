import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({Key? key}) : super(key: key);

  @override
  _AdminNotificationsScreenState createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingRequests();
  }

  Future<void> _fetchPendingRequests() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('is_verified', false)
          .inFilter('role', const ['Lawyer', 'Advocate Clerk']);

      if (mounted) {
        setState(() {
          _pendingRequests = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching pending requests: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Admin Notifications', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No new notifications',
                        style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendingRequests.length,
                  itemBuilder: (context, index) {
                    final request = _pendingRequests[index];
                    final role = request['role'] ?? 'Unknown';
                    final username = request['username'] ?? 'Unknown User';
                    final time = request['created_at'] != null 
                        ? DateTime.parse(request['created_at']).toLocal().toString().substring(0, 16)
                        : 'Recently';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                          child: Icon(Icons.person_add, color: Theme.of(context).primaryColor),
                        ),
                        title: Text('New $role Registration', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        subtitle: Text('$username has registered and is awaiting verification.\n$time'),
                        isThreeLine: true,
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Go back to dashboard so they can review it in the tabs
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please check the Management tabs to review.'))
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
