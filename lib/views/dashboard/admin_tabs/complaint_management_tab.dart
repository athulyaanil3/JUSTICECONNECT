import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchComplaints() async {
    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> results = [];
      final Set<String> seenIds = {};

      // 1. Fetch from dedicated complaints table if available
      try {
        final response = await _supabase
            .from('complaints')
            .select()
            .order('created_at', ascending: false);
        for (var c in response) {
          final id = c['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            seenIds.add(id);
            results.add(Map<String, dynamic>.from(c));
          }
        }
      } catch (e) {
        debugPrint('Complaints table query notice: $e');
      }

      // 2. Fetch from app_notifications where target_user = 'Admin' and title contains 'Complaint'
      try {
        final notifs = await _supabase
            .from('app_notifications')
            .select()
            .eq('target_user', 'Admin')
            .ilike('title', '%Complaint%')
            .order('created_at', ascending: false);

        for (var n in notifs) {
          final notifId = n['id']?.toString() ?? '';
          if (n['action_payload'] != null && n['action_payload'].toString().isNotEmpty) {
            try {
              final payload = jsonDecode(n['action_payload'].toString());
              if (payload is Map<String, dynamic>) {
                final complaintId = payload['id']?.toString() ?? notifId;
                if (!seenIds.contains(complaintId)) {
                  seenIds.add(complaintId);
                  results.add(payload);
                }
              }
            } catch (_) {
              if (!seenIds.contains(notifId)) {
                seenIds.add(notifId);
                results.add({
                  'id': notifId,
                  'title': n['title'] ?? 'Complaint',
                  'description': n['message'] ?? '',
                  'category': 'General Grievance / Feedback',
                  'priority': 'Medium',
                  'status': (n['is_read'] == true) ? 'Resolved' : 'Pending',
                  'user_name': 'Citizen/User',
                  'user_email': '',
                  'user_role': 'Citizen',
                  'created_at': n['created_at'],
                });
              }
            }
          } else {
            if (!seenIds.contains(notifId)) {
              seenIds.add(notifId);
              results.add({
                'id': notifId,
                'title': n['title'] ?? 'Complaint',
                'description': n['message'] ?? '',
                'category': 'General Grievance / Feedback',
                'priority': 'Medium',
                'status': (n['is_read'] == true) ? 'Resolved' : 'Pending',
                'user_name': 'Citizen/User',
                'user_email': '',
                'user_role': 'Citizen',
                'created_at': n['created_at'],
              });
            }
          }
        }
      } catch (e) {
        debugPrint('app_notifications complaint query notice: $e');
      }

      results.sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
        final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _complaints = results;
        });
      }
    } catch (e) {
      debugPrint('Error fetching complaints: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateComplaintStatus(String id, String newStatus, {String? adminResponse}) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (adminResponse != null && adminResponse.isNotEmpty) {
        updateData['admin_response'] = adminResponse;
      }

      // 1. Update in complaints table if it exists
      try {
        await _supabase
            .from('complaints')
            .update(updateData)
            .eq('id', id);
      } catch (e) {
        debugPrint('Complaints table update notice: $e');
      }

      // 2. Update in app_notifications if exists
      try {
        final notifQuery = await _supabase
            .from('app_notifications')
            .select()
            .eq('id', id)
            .maybeSingle();

        if (notifQuery != null) {
          Map<String, dynamic> payload = {};
          if (notifQuery['action_payload'] != null && notifQuery['action_payload'].toString().isNotEmpty) {
            try {
              payload = jsonDecode(notifQuery['action_payload'].toString());
            } catch (_) {}
          }
          payload['status'] = newStatus;
          if (adminResponse != null) {
            payload['admin_response'] = adminResponse;
          }
          await _supabase.from('app_notifications').update({
            'action_payload': jsonEncode(payload),
            'is_read': newStatus == 'Resolved',
          }).eq('id', id);
        }
      } catch (e) {
        debugPrint('app_notifications update notice: $e');
      }

      // 3. Notify the citizen/lawyer about complaint update
      final complaint = _complaints.firstWhere((c) => c['id'].toString() == id, orElse: () => {});
      final userEmail = complaint['user_email']?.toString();
      if (userEmail != null && userEmail.isNotEmpty) {
        try {
          await _supabase.from('app_notifications').insert({
            'id': 'reply_${DateTime.now().millisecondsSinceEpoch}',
            'target_user': userEmail,
            'title': 'Complaint $newStatus: ${complaint['title'] ?? ''}',
            'message': adminResponse != null && adminResponse.isNotEmpty
                ? 'Admin resolution: $adminResponse'
                : 'Your complaint status has been updated to "$newStatus" by Administration.',
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }
      
      // Optimistic update
      if (mounted) {
        setState(() {
          final index = _complaints.indexWhere((c) => c['id'].toString() == id);
          if (index != -1) {
            _complaints[index]['status'] = newStatus;
            if (adminResponse != null) {
              _complaints[index]['admin_response'] = adminResponse;
            }
          }
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Complaint marked as $newStatus'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error updating complaint status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showResolveDialog(Map<String, dynamic> complaint) {
    final responseController = TextEditingController(text: complaint['admin_response'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text('Resolve Complaint'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Complaint: ${complaint['title'] ?? ''}', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: responseController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Resolution Remarks / Action Taken',
                hintText: 'Enter note to be visible to the user...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _updateComplaintStatus(
                complaint['id'].toString(), 
                'Resolved',
                adminResponse: responseController.text.trim(),
              );
            },
            child: const Text('Confirm Resolution'),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'Lawyer':
        return Colors.indigo;
      case 'Advocate Clerk':
        return Colors.teal;
      case 'Citizen':
      default:
        return Colors.blue;
    }
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'Urgent':
        return Colors.red;
      case 'High':
        return Colors.orange;
      case 'Medium':
        return Colors.blue;
      case 'Low':
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF0D256C),
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: const Color(0xFF0D256C),
            indicatorWeight: 3,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Pending'),
                    const SizedBox(width: 6),
                    _buildCountBadge('Pending'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('In Progress'),
                    const SizedBox(width: 6),
                    _buildCountBadge('In Progress'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Resolved'),
                    const SizedBox(width: 6),
                    _buildCountBadge('Resolved'),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _buildCountBadge(String status) {
    final count = _complaints.where((c) => (c['status'] ?? 'Pending') == status).length;
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: status == 'Pending' ? Colors.red : (status == 'In Progress' ? Colors.orange : Colors.green),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildComplaintList(String statusFilter) {
    final filtered = _complaints.where((c) => (c['status'] ?? 'Pending') == statusFilter).toList();
    
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 54, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No $statusFilter complaints.',
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 16),
            ),
          ],
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
          final role = complaint['user_role'] ?? 'Citizen';
          final priority = complaint['priority'] ?? 'Medium';
          final category = complaint['category'] ?? 'General';
          final submitter = complaint['user_name'] ?? complaint['user_email'] ?? 'Anonymous';
          final email = complaint['user_email'] ?? '';
          final createdAt = DateTime.tryParse(complaint['created_at']?.toString() ?? '')?.toLocal();

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: _getRoleColor(role).withOpacity(0.12),
                child: Icon(
                  role == 'Lawyer' ? Icons.gavel : (role == 'Advocate Clerk' ? Icons.badge : Icons.person),
                  color: _getRoleColor(role),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      complaint['title'] ?? 'Complaint',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(priority).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      priority,
                      style: TextStyle(color: _getPriorityColor(priority), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getRoleColor(role).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(role, style: TextStyle(color: _getRoleColor(role), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$submitter ($email)',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$category • ${createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt) : 'Recently'}',
                    style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey[500]),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Complaint Description:',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              complaint['description'] ?? 'No description provided.',
                              style: GoogleFonts.inter(fontSize: 13.5, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      if (complaint['admin_response'] != null && complaint['admin_response'].toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Admin Remarks:',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green[800]),
                              ),
                              const SizedBox(height: 4),
                              Text(complaint['admin_response'].toString(), style: GoogleFonts.inter(fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        children: [
                          if (statusFilter != 'In Progress' && statusFilter != 'Resolved')
                            OutlinedButton.icon(
                              onPressed: () => _updateComplaintStatus(complaint['id'].toString(), 'In Progress'),
                              icon: const Icon(Icons.hourglass_top, size: 16),
                              label: const Text('Mark In Progress'),
                            ),
                          if (statusFilter != 'Resolved')
                            ElevatedButton.icon(
                              onPressed: () => _showResolveDialog(complaint),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Resolve with Note'),
                            ),
                          if (statusFilter == 'Resolved')
                            OutlinedButton.icon(
                              onPressed: () => _updateComplaintStatus(complaint['id'].toString(), 'Pending'),
                              icon: const Icon(Icons.replay, size: 16),
                              label: const Text('Reopen Complaint'),
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
