import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class SubmitComplaintScreen extends StatefulWidget {
  final String? initialCategory;

  const SubmitComplaintScreen({
    Key? key,
    this.initialCategory,
  }) : super(key: key);

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  late TabController _tabController;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  
  String _selectedCategory = 'App Bug / Technical Issue';
  String _selectedPriority = 'Medium';

  bool _isSubmitting = false;
  bool _isLoadingHistory = false;
  List<Map<String, dynamic>> _myComplaints = [];

  String _userName = 'User';
  String _userEmail = '';
  String _userRole = 'Citizen';

  final List<String> _categories = [
    'App Bug / Technical Issue',
    'Account & Verification Problem',
    'Advocate / Lawyer Conduct',
    'Advocate Clerk Issue',
    'Consultation / Fee Dispute',
    'Harassment or Inappropriate Behavior',
    'General Grievance / Feedback',
  ];

  final List<String> _priorities = ['Low', 'Medium', 'High', 'Urgent'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialCategory != null && _categories.contains(widget.initialCategory)) {
      _selectedCategory = widget.initialCategory!;
    }
    _loadUserInfo();
    _fetchMyComplaints();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _userEmail = user.email ?? '';
      try {
        final profile = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();
        if (profile != null && mounted) {
          setState(() {
            _userName = profile['username'] ?? user.userMetadata?['username'] ?? 'User';
            _userRole = profile['role'] ?? user.userMetadata?['role'] ?? 'Citizen';
          });
          return;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _userName = user.userMetadata?['username'] ?? 'User';
          _userRole = user.userMetadata?['role'] ?? 'Citizen';
        });
      }
    }
  }

  Future<void> _fetchMyComplaints() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoadingHistory = true);
    try {
      final List<Map<String, dynamic>> list = [];
      final Set<String> seenIds = {};

      // 1. Try complaints table
      try {
        final res = await _supabase
            .from('complaints')
            .select()
            .or('user_id.eq.${user.id},user_email.eq.${user.email}')
            .order('created_at', ascending: false);
        for (var item in res) {
          final id = item['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            seenIds.add(id);
            list.add(Map<String, dynamic>.from(item));
          }
        }
      } catch (e) {
        debugPrint('Complaints table read notice: $e');
      }

      // 2. Fallback to app_notifications for complaints filed by this user
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
                if ((payload['user_id'] == user.id || payload['user_email'] == user.email) &&
                    !seenIds.contains(complaintId)) {
                  seenIds.add(complaintId);
                  list.add(payload);
                }
              }
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('app_notifications read notice: $e');
      }

      list.sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
        final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _myComplaints = list;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user complaints: $e');
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _supabase.auth.currentUser;
    setState(() => _isSubmitting = true);

    final complaintId = 'complaint_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();

    final complaintData = {
      'id': complaintId,
      'user_id': user?.id,
      'user_name': _userName,
      'user_email': _userEmail,
      'user_role': _userRole,
      'category': _selectedCategory,
      'priority': _selectedPriority,
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'status': 'Pending',
      'created_at': now,
      'updated_at': now,
    };

    try {
      bool delivered = false;

      // 1. Guaranteed delivery to Admin via app_notifications table
      try {
        await _supabase.from('app_notifications').insert({
          'id': complaintId,
          'target_user': 'Admin',
          'title': 'New Complaint: ${_titleController.text.trim()}',
          'message': '$_userRole $_userName has filed a $_selectedPriority priority complaint under "$_selectedCategory".\n\n${_descController.text.trim()}',
          'is_read': false,
          'action_payload': jsonEncode(complaintData),
          'created_at': now,
        });
        delivered = true;
      } catch (notifErr) {
        debugPrint('Notice on app_notifications insert: $notifErr');
      }

      // 2. Also insert into complaints table
      try {
        await _supabase.from('complaints').insert(complaintData);
        delivered = true;
      } catch (complaintTableErr) {
        debugPrint('Notice on complaints table insert: $complaintTableErr');
      }

      if (!delivered) {
        throw Exception('Could not reach server to deliver complaint. Please check your internet connection.');
      }

      if (!mounted) return;

      _titleController.clear();
      _descController.clear();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('Complaint Submitted'),
            ],
          ),
          content: Text(
            'Your grievance has been officially registered and forwarded to the JusticeConnect Administration team. You can track updates under "My Complaints".',
            style: GoogleFonts.inter(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _fetchMyComplaints();
                _tabController.animateTo(1);
              },
              child: const Text('View Status'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error submitting complaint: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit complaint: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Color _getPriorityColor(String priority) {
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Resolved':
        return Colors.green;
      case 'In Progress':
        return Colors.orange;
      case 'Pending':
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Grievance & Support',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: primaryColor,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.report_problem_outlined), text: 'File Complaint'),
            Tab(icon: Icon(Icons.history), text: 'My Complaints'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFormTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildFormTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User identity banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(_userName.isNotEmpty ? _userName[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Submitting as: $_userName', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Role: $_userRole • $_userEmail', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Category selector
            Text('Issue Category', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.category_outlined),
              ),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.inter(fontSize: 14)))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 18),

            // Priority level
            Text('Urgency / Priority', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: _priorities.map((p) {
                final isSelected = _selectedPriority == p;
                final color = _getPriorityColor(p);
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(p),
                    selected: isSelected,
                    selectedColor: color.withOpacity(0.18),
                    labelStyle: TextStyle(
                      color: isSelected ? color : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(color: isSelected ? color : Colors.grey[300]!),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedPriority = p);
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Title
            Text('Subject / Summary', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Brief summary of your complaint or issue',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.title_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter a subject';
                if (v.trim().length < 5) return 'Subject should be at least 5 characters';
                return null;
              },
            ),
            const SizedBox(height: 18),

            // Description
            Text('Detailed Description', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Provide full details, including dates, names, case numbers, or steps to reproduce the issue...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please describe the problem in detail';
                if (v.trim().length < 15) return 'Please enter at least 15 characters of detail';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting ? null : _submitComplaint,
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isSubmitting ? 'Submitting to Admin...' : 'Submit Grievance to Admin',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                'Submissions are directly monitored by the JusticeConnect Admin panel.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myComplaints.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchMyComplaints,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 40),
            Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Complaints Filed',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'You haven\'t submitted any complaints or grievances yet. Any issues you submit will appear here with live updates from the admin team.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13, height: 1.4),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMyComplaints,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myComplaints.length,
        itemBuilder: (context, index) {
          final c = _myComplaints[index];
          final status = c['status']?.toString() ?? 'Pending';
          final priority = c['priority']?.toString() ?? 'Medium';
          final createdAt = DateTime.tryParse(c['created_at']?.toString() ?? '')?.toLocal();

          return Card(
            elevation: 1.5,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ExpansionTile(
              leading: Icon(
                status == 'Resolved' ? Icons.check_circle : (status == 'In Progress' ? Icons.hourglass_top : Icons.warning_amber),
                color: _getStatusColor(status),
                size: 28,
              ),
              title: Text(
                c['title'] ?? 'Complaint',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Text(
                '${c['category'] ?? 'General'} • ${createdAt != null ? DateFormat('dd MMM yyyy').format(createdAt) : 'Recently'}',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
              ),
              trailing: Chip(
                label: Text(status, style: TextStyle(color: _getStatusColor(status), fontSize: 11, fontWeight: FontWeight.bold)),
                backgroundColor: _getStatusColor(status).withOpacity(0.12),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(priority).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Priority: $priority',
                              style: TextStyle(color: _getPriorityColor(priority), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Description:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(c['description'] ?? 'No description provided', style: GoogleFonts.inter(fontSize: 13.5, color: Colors.black87, height: 1.4)),
                      if (c['admin_response'] != null && c['admin_response'].toString().isNotEmpty) ...[
                        const Divider(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.support_agent, color: Colors.green, size: 18),
                                  const SizedBox(width: 6),
                                  Text('Admin Response / Action Taken:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green[800])),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(c['admin_response'].toString(), style: GoogleFonts.inter(fontSize: 13, color: Colors.black87)),
                            ],
                          ),
                        ),
                      ],
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
