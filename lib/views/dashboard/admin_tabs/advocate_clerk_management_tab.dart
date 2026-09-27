import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdvocateClerkManagementTab extends StatefulWidget {
  const AdvocateClerkManagementTab({Key? key}) : super(key: key);

  @override
  _AdvocateClerkManagementTabState createState() => _AdvocateClerkManagementTabState();
}

class _AdvocateClerkManagementTabState extends State<AdvocateClerkManagementTab> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  
  List<Map<String, dynamic>> _clerks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchClerks();
  }

  Future<void> _fetchClerks() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'Advocate Clerk');

      setState(() {
        _clerks = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error fetching clerks: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateClerkStatus(String id, bool verify) async {
    try {
      await _supabase
          .from('profiles')
          .update({'is_verified': verify})
          .eq('id', id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(verify ? 'Advocate Clerk Verified' : 'Advocate Clerk Suspended'),
          backgroundColor: verify ? Colors.green : Colors.red,
        ),
      );
      
      _fetchClerks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _removeClerk(String id) async {
    try {
      await _supabase.from('profiles').delete().eq('id', id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Advocate Clerk Removed'), backgroundColor: Colors.red),
      );
      
      _fetchClerks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showReviewDialog(Map<String, dynamic> clerk) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Review Advocate Clerk Registration', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Name', clerk['username'] ?? 'Unknown'),
                _buildDetailRow('Email', clerk['email'] ?? 'N/A'),
                const Divider(height: 32),
                Text('Verification Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                _buildDetailRow('Employee ID', clerk['enrollment_number'] ?? 'EMP12345 (Mock)'),
                _buildDetailRow('District', clerk['district'] ?? 'Thiruvananthapuram (Mock)'),
                const SizedBox(height: 16),
                Text('Uploaded Documents', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'clerk_id.pdf',
                          style: GoogleFonts.inter(color: Colors.blue[700], decoration: TextDecoration.underline),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Downloading document...')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateClerkStatus(clerk['id'], false); // Reject/Suspend
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Reject'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateClerkStatus(clerk['id'], true); // Approve
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: GoogleFonts.inter(color: Colors.grey[700], fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCreateAccountDialog() {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Create Advocate Clerk', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This requires Supabase Auth API integration for actual signup.'),
                  ),
                );
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _showCreateAccountDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Advocate Clerk Account'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Verified'),
            Tab(text: 'Rejected'),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildClerkList(_clerks),
                    _buildClerkList(_clerks.where((l) => l['is_verified'] == null).toList()),
                    _buildClerkList(_clerks.where((l) => l['is_verified'] == true).toList()),
                    _buildClerkList(_clerks.where((l) => l['is_verified'] == false).toList()),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildClerkList(List<Map<String, dynamic>> clerks) {
    if (clerks.isEmpty) {
      return Center(
        child: Text(
          'No Advocate Clerks found.',
          style: GoogleFonts.inter(color: Colors.grey, fontSize: 16),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchClerks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: clerks.length,
        itemBuilder: (context, index) {
          final clerk = clerks[index];
          final isVerified = clerk['is_verified'] == true;
          final isRejected = clerk['is_verified'] == false;
          final isPending = clerk['is_verified'] == null;
          
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: isVerified ? Colors.green.withOpacity(0.1) : (isRejected ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1)),
                child: Icon(Icons.gavel, color: isVerified ? Colors.green : (isRejected ? Colors.red : Colors.orange)),
              ),
              title: Text(
                clerk['username'] ?? 'Unknown Clerk',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Text(
                'Status: ${isVerified ? "Verified" : (isRejected ? "Rejected/Suspended" : "Pending")}\nEmail: ${clerk['email'] ?? 'N/A'}',
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isVerified)
                    IconButton(
                      icon: const Icon(Icons.block, color: Colors.orange),
                      onPressed: () => _updateClerkStatus(clerk['id'], false),
                      tooltip: 'Suspend',
                    )
                  else if (isPending)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showReviewDialog(clerk),
                      child: const Text('Review'),
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _updateClerkStatus(clerk['id'], true),
                      child: const Text('Restore'),
                    ),
                  if (isVerified || isRejected)
                    const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeClerk(clerk['id']),
                    tooltip: 'Remove',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
