import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ComplaintManagementTab extends StatefulWidget {
  const ComplaintManagementTab({Key? key}) : super(key: key);

  @override
  _ComplaintManagementTabState createState() => _ComplaintManagementTabState();
}

class _ComplaintManagementTabState extends State<ComplaintManagementTab> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  
  List<Map<String, dynamic>> _complaints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchComplaints();
  }

  Future<void> _fetchComplaints() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('complaints')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        _complaints = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error fetching complaints, falling back to mock data: $e');
      // Fallback to mock data if table doesn't exist yet
      setState(() {
        _complaints = [
          {
            'id': '1',
            'title': 'App Crashing on Case Upload',
            'description': 'When I try to upload a PDF, the app crashes.',
            'status': 'Pending',
            'user_email': 'citizen1@test.com',
            'created_at': DateTime.now().toIso8601String(),
          },
          {
            'id': '2',
            'title': 'Cannot see my verified status',
            'description': 'I have been verified but my dashboard still says pending.',
            'status': 'In Progress',
            'user_email': 'lawyer1@test.com',
            'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          },
          {
            'id': '3',
            'title': 'Spam messages in chat',
            'description': 'Getting unsolicited messages from other users.',
            'status': 'Resolved',
            'user_email': 'citizen2@test.com',
            'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
          },
        ];
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateComplaintStatus(String id, String newStatus) async {
    try {
      // Optimistic update for mock data
      setState(() {
        final index = _complaints.indexWhere((c) => c['id'] == id);
        if (index != -1) {
          _complaints[index]['status'] = newStatus;
        }
      });
      
      // Try DB update
      await _supabase
          .from('complaints')
          .update({'status': newStatus})
          .eq('id', id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Complaint status updated to $newStatus'), backgroundColor: Colors.green),
      );
    } catch (e) {
      debugPrint('Error updating complaint (might be mock data): $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated locally (Mock mode)'), backgroundColor: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'In Progress'),
            Tab(text: 'Resolved'),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildComplaintList('Pending'),
                    _buildComplaintList('In Progress'),
                    _buildComplaintList('Resolved'),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildComplaintList(String statusFilter) {
    final filtered = _complaints.where((c) => c['status'] == statusFilter).toList();
    
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No $statusFilter complaints.',
          style: GoogleFonts.inter(color: Colors.grey, fontSize: 16),
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _fetchComplaints,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final complaint = filtered[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              leading: Icon(
                statusFilter == 'Resolved' ? Icons.check_circle : 
                statusFilter == 'In Progress' ? Icons.hourglass_top : Icons.warning,
                color: statusFilter == 'Resolved' ? Colors.green : 
                       statusFilter == 'In Progress' ? Colors.orange : Colors.red,
              ),
              title: Text(
                complaint['title'] ?? 'No Title',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'By: ${complaint['user_email'] ?? 'Unknown'} • ${complaint['created_at'].toString().substring(0, 10)}',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Description:',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        complaint['description'] ?? 'No description provided.',
                        style: GoogleFonts.inter(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (statusFilter != 'In Progress' && statusFilter != 'Resolved')
                            TextButton(
                              onPressed: () => _updateComplaintStatus(complaint['id'], 'In Progress'),
                              child: const Text('Mark In Progress'),
                            ),
                          if (statusFilter != 'Resolved')
                            ElevatedButton(
                              onPressed: () => _updateComplaintStatus(complaint['id'], 'Resolved'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              child: const Text('Resolve'),
                            ),
                          if (statusFilter == 'Resolved')
                            OutlinedButton(
                              onPressed: () => _updateComplaintStatus(complaint['id'], 'Pending'),
                              child: const Text('Reopen'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
