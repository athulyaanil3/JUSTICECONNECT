import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../controllers/request_provider.dart';
import '../../../controllers/notification_provider.dart';
import '../../../controllers/lawyer_provider.dart';
import '../../../models/app_notification.dart';
import '../../../models/consultation_request.dart';
import '../../chat/chat_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class ClientManagementTab extends StatefulWidget {
  const ClientManagementTab({Key? key}) : super(key: key);

  @override
  _ClientManagementTabState createState() => _ClientManagementTabState();
}

class _ClientManagementTabState extends State<ClientManagementTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _pendingClerks = [];
  List<Map<String, dynamic>> _activeClerks = [];

  @override
  void initState() {
    super.initState();
    _fetchClerks();
  }

  Future<void> _fetchClerks() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final pendingData = await _supabase.from('profiles')
            .select()
            .eq('role', 'Advocate Clerk')
            .eq('associated_lawyer_id', user.id)
            .isFilter('is_verified', null);
            
        final activeData = await _supabase.from('profiles')
            .select()
            .eq('role', 'Advocate Clerk')
            .eq('associated_lawyer_id', user.id)
            .eq('is_verified', true);
            
        if (mounted) {
          setState(() {
            _pendingClerks = List<Map<String, dynamic>>.from(pendingData);
            _activeClerks = List<Map<String, dynamic>>.from(activeData);
          });
        }
      } catch (e) {
        debugPrint('Error fetching clerks: $e');
      }
    }
  }

  void _showTakeCaseDialog(BuildContext context, ConsultationRequest request) async {
    final titleController = TextEditingController(text: 'Case for ${request.citizenName}');
    final categoryController = TextEditingController();
    
    final lawyerProvider = Provider.of<LawyerProvider>(context, listen: false);
    final clerks = await lawyerProvider.fetchAvailableClerks();
    String? selectedClerkId;
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Take Case'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Convert this consultation into a formal court case.', style: GoogleFonts.inter(fontSize: 14)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Case Title', hintText: 'e.g. Property Dispute'),
                  ),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Category', hintText: 'e.g. Civil'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedClerkId,
                    hint: const Text('Assign Advocate Clerk (Optional)'),
                    items: clerks.map((clerk) => DropdownMenuItem(
                      value: clerk['id'] as String,
                      child: Text(clerk['username'] ?? 'Unknown Clerk'),
                    )).toList(),
                    onChanged: (val) {
                      setState(() => selectedClerkId = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isNotEmpty && categoryController.text.isNotEmpty) {
                    // 1. Submit Case
                    await lawyerProvider.submitNewCaseFile(
                      titleController.text,
                      categoryController.text,
                      request.issueDescription,
                      request.citizenName, // Using citizenName as clientId for linking
                      advocateClerkId: selectedClerkId,
                    );
                    
                    // 2. Notify User
                    final notification = AppNotification(
                      id: Uuid().v4(),
                      title: 'Case Started!',
                      message: '${request.lawyerName} has officially taken your case: ${titleController.text}.',
                      timestamp: DateTime.now(),
                      actionPayload: request.id,
                    );
                    Provider.of<NotificationProvider>(context, listen: false).addNotification(notification, request.citizenName);
                    
                    // 3. Update Consultation Request Status
                    await Provider.of<RequestProvider>(context, listen: false).updateRequestStatus(request.id, 'Case Started');
                    
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Case officially taken and submitted!'), backgroundColor: Colors.green));
                    }
                  }
                },
                child: const Text('Take Case'),
              )
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Clients',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'New Requests',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Consumer<RequestProvider>(
            builder: (context, requestProvider, child) {
              final pendingRequests = requestProvider.requests.where((r) => r.status == 'Pending').toList();
              
              if (pendingRequests.isEmpty) {
                return Text('No new requests right now.', style: GoogleFonts.inter(color: Colors.grey));
              }

              return Column(
                children: pendingRequests.map((req) {
                  return _buildClientRequestCard(context, req);
                }).toList(),
              );
            },
          ),
          
          const SizedBox(height: 24),
          Text(
            'Active Clients',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Consumer<RequestProvider>(
            builder: (context, requestProvider, child) {
              final activeClients = requestProvider.requests.where((r) => r.status == 'Accepted' || r.status == 'Confirmed' || r.status == 'Case Started').toList();
              
              if (activeClients.isEmpty) {
                return Text('No active clients yet.', style: GoogleFonts.inter(color: Colors.grey));
              }

              return Column(
                children: activeClients.map((req) {
                  return _buildActiveClientCard(context, req);
                }).toList(),
              );
            },
          ),
          
          if (_pendingClerks.isNotEmpty || _activeClerks.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'My Staff & Clerks',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
          ],
          
          if (_pendingClerks.isNotEmpty)
            ..._pendingClerks.map((clerk) => Card(
              color: Colors.orange[50],
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.orange[200]!)),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.person, color: Colors.white)),
                title: Text(clerk['username'] ?? 'Unknown', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                subtitle: Text('Pending Approval • Court: ${clerk['court_id']}'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: () async {
                    try {
                      await _supabase.from('profiles').update({'is_verified': true}).eq('id', clerk['id']);
                      _fetchClerks();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clerk Approved!')));
                    } catch (e) {
                      debugPrint('Error approving clerk: $e');
                    }
                  },
                  child: const Text('Approve'),
                ),
              ),
            )).toList(),

          if (_activeClerks.isNotEmpty)
            ..._activeClerks.map((clerk) => Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Colors.blue[100], child: const Icon(Icons.person, color: Colors.blue)),
                title: Text(clerk['username'] ?? 'Unknown', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                subtitle: Text('Active Clerk • District: ${clerk['court_district']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.person_remove, color: Colors.red),
                  tooltip: 'Remove Clerk',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Remove Clerk?'),
                        content: Text('Are you sure you want to remove ${clerk['username']} from your office?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Remove'),
                          )
                        ],
                      ),
                    );

                    if (confirm == true) {
                      try {
                        await _supabase.from('profiles').update({'is_verified': false, 'associated_lawyer_id': null}).eq('id', clerk['id']);
                        _fetchClerks();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clerk removed successfully.')));
                      } catch (e) {
                        debugPrint('Error removing clerk: $e');
                      }
                    }
                  },
                ),
              ),
            )).toList(),
        ],
      ),
    );
  }

  Widget _buildClientRequestCard(BuildContext context, ConsultationRequest request) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange[100],
                  child: Icon(Icons.person_add, color: Colors.orange[800]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.citizenName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('To: ${request.lawyerName}', style: GoogleFonts.inter(color: Theme.of(context).primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('Issue: ${request.issueDescription}', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Provider.of<RequestProvider>(context, listen: false).updateRequestStatus(request.id, 'Rejected');
                      
                      // Send Rejection Notification
                      final notification = AppNotification(
                        id: Uuid().v4(),
                        title: 'Request Rejected',
                        message: '${request.lawyerName} is unable to take your consultation request at this time.',
                        timestamp: DateTime.now(),
                        actionPayload: request.id,
                      );
                      Provider.of<NotificationProvider>(context, listen: false).addNotification(notification, request.citizenName);
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // 1. Call lawyerProceedsRequest to set status to 'Awaiting Confirmation' and notify user
                      await Provider.of<RequestProvider>(context, listen: false).lawyerProceedsRequest(request.id, request.citizenName);
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proceeded. Awaiting User Confirmation.')));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    child: const Text('Proceed'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActiveClientCard(BuildContext context, ConsultationRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(Icons.person, color: Theme.of(context).primaryColor),
        ),
        title: Text(request.citizenName, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        subtitle: Text('Issue: ${request.issueDescription}', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chat, color: Colors.blue), 
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      requestId: request.id,
                      otherPersonName: request.citizenName,
                      isLawyer: true, // Lawyer
                    ),
                  ),
                );
              },
            ),
            ElevatedButton(
              onPressed: () => _showTakeCaseDialog(context, request),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.black,
              ),
              child: const Text('Take Case'),
            ),
          ],
        ),
      ),
    );
  }
}
