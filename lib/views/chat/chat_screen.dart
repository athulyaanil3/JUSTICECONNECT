import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
// removed flutter_windowmanager import

import '../../controllers/request_provider.dart';
import '../../controllers/lawyer_provider.dart';
import '../../controllers/notification_provider.dart';
import '../../models/consultation_request.dart';
import '../../models/app_notification.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/evidence_encryption_service.dart';
import '../../services/pattern_verification_service.dart';
import '../shared/secure_evidence_viewer.dart';
import '../dashboard/chat/filing_chat_screen.dart';
import '../../models/legal_case.dart';

class ChatScreen extends StatefulWidget {
  final String requestId;
  final String otherPersonName;
  final bool isLawyer; // Determines message alignment

  const ChatScreen({
    Key? key, 
    required this.requestId, 
    required this.otherPersonName, 
    required this.isLawyer
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _secureScreen();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RequestProvider>(context, listen: false).fetchRequests();
    });
  }

  Future<void> _secureScreen() async {
    // await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
  }

  @override
  void dispose() {
    // FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final message = {
      'text': _messageController.text.trim(),
      'sender': widget.isLawyer ? 'Lawyer' : 'Citizen',
      'time': DateFormat('hh:mm a').format(DateTime.now()),
    };

    Provider.of<RequestProvider>(context, listen: false)
        .addMessageToRequest(widget.requestId, message);

    _messageController.clear();
    
    // Scroll to bottom after sending
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _uploadEncryptedFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'mp4'],
      );

      if (result.isEmpty) return;
      
      final files = result.map((f) => File(f.path!)).toList();
      
      num totalSize = 0;
      for (var f in files) {
        totalSize += await f.length();
      }
      if (totalSize > 50 * 1024 * 1024) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Total file size must not exceed 50MB.')));
        return;
      }

      // 🔐 Security Code Verification Before Sending 🔐
      final isAuthenticated = await PatternVerificationService.authenticate(
        context: context,
        reason: 'Please enter your 4-digit security code to authorize this secure evidence transfer.',
        userKey: Supabase.instance.client.auth.currentUser?.email,
      );

      if (!isAuthenticated) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Security code verification failed. File not sent.')));
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Encrypting & Sending securely...'),
            ],
          ),
        ),
      );

      final encryptionService = EvidenceEncryptionService();
      final encryptionResult = await encryptionService.encryptEvidencePackage(files);
      
      final documentId = const Uuid().v4();
      final storagePath = '${widget.requestId}/$documentId.enc';
      final supabase = Supabase.instance.client;

      // Upload encrypted file as raw binary
      await supabase.storage.from('case-evidence').upload(
        storagePath, 
        encryptionResult.encryptedFile,
        fileOptions: const FileOptions(contentType: 'application/octet-stream'),
      );

      // Insert metadata
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('case_documents').insert({
        'id': documentId,
        'case_id': widget.requestId,
        'uploaded_by': userId,
        'document_type': 'Evidence Package',
        'document_name': 'Encrypted Chat Evidence',
        'storage_path': storagePath,
        'file_size': await encryptionResult.encryptedFile.length(),
        'mime_type': 'application/octet-stream',
        'encryption_algorithm': encryptionResult.algorithm,
        'encryption_version': encryptionResult.version,
        'encrypted_key': encryptionResult.keyBase64,
        'nonce': encryptionResult.nonceBase64,
        'verification_status': 'Pending',
      });

      // Cleanup temp encrypted file
      if (await encryptionResult.encryptedFile.exists()) {
        await encryptionResult.encryptedFile.delete();
      }

      if (mounted) Navigator.pop(context); // Close loading

      // Send chat message
      final message = {
        'text': '[ENCRYPTED_FILE]',
        'sender': widget.isLawyer ? 'Lawyer' : 'Citizen',
        'time': DateFormat('hh:mm a').format(DateTime.now()),
      };
      Provider.of<RequestProvider>(context, listen: false)
          .addMessageToRequest(widget.requestId, message);

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Upload error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
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
                    await lawyerProvider.submitNewCaseFile(
                      titleController.text,
                      categoryController.text,
                      request.issueDescription,
                      request.citizenName, // Using citizenName as clientId for linking
                      advocateClerkId: selectedClerkId,
                    );
                    
                    final notification = AppNotification(
                      id: Uuid().v4(),
                      title: 'Case Started!',
                      message: '${request.lawyerName} has officially taken your case: ${titleController.text}.',
                      timestamp: DateTime.now(),
                      actionPayload: request.id,
                    );
                    Provider.of<NotificationProvider>(context, listen: false).addNotification(notification, request.citizenName);
                    
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

  Future<void> _openClerkChat(BuildContext context) async {
    final lawyerProvider = Provider.of<LawyerProvider>(context, listen: false);
    
    // 1. Fetch available clerks for this lawyer
    final clerks = await lawyerProvider.fetchAvailableClerks();
    if (!context.mounted) return;

    if (clerks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No advocate clerks currently assigned to your office. You can approve and assign clerks in Client Management.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Find if this client has an existing case with an assigned clerk
    final matchingCases = lawyerProvider.myCases.where((c) {
      return c.userId.toLowerCase() == widget.otherPersonName.toLowerCase() ||
          c.title.toLowerCase().contains(widget.otherPersonName.toLowerCase());
    }).toList();

    LegalCase? assignedCase;
    for (var c in matchingCases) {
      if (c.advocateClerkId.isNotEmpty) {
        assignedCase = c;
        break;
      }
    }

    if (assignedCase != null) {
      final foundCase = assignedCase;
      final assignedClerk = clerks.firstWhere(
        (cl) => cl['id'] == foundCase.advocateClerkId,
        orElse: () => {'username': 'Assigned Clerk', 'id': foundCase.advocateClerkId},
      );
      final clerkName = assignedClerk['username'] ?? 'Assigned Clerk';
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FilingChatScreen(
            filingId: foundCase.id,
            filingTitle: '${foundCase.title} (Clerk: $clerkName)',
            currentUserRole: 'Lawyer',
          ),
        ),
      );
      return;
    }

    // 3. If no clerk assigned yet, show selection sheet so lawyer can choose which clerk to chat with
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.support_agent, color: Color(0xFF0D256C), size: 28),
                const SizedBox(width: 12),
                Text(
                  'Chat with Advocate Clerk',
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select an advocate clerk to coordinate on this matter:',
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
            ),
            const Divider(height: 24),
            ...clerks.map((clerk) {
              final clerkId = clerk['id'] as String;
              final clerkName = (clerk['username'] ?? 'Clerk').toString();

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF0D256C).withOpacity(0.1),
                  child: const Icon(Icons.person, color: Color(0xFF0D256C)),
                ),
                title: Text(clerkName, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                subtitle: const Text('Advocate Clerk', style: TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: const Icon(Icons.chat_bubble_outline, color: Color(0xFF0D256C)),
                onTap: () {
                  Navigator.pop(ctx);
                  final caseId = matchingCases.isNotEmpty 
                      ? matchingCases.first.id 
                      : 'consultation_${widget.requestId}';
                  final caseTitle = matchingCases.isNotEmpty 
                      ? matchingCases.first.title 
                      : 'Client: ${widget.otherPersonName}';

                  if (matchingCases.isNotEmpty && matchingCases.first.advocateClerkId.isEmpty) {
                    lawyerProvider.assignAdvocateClerk(matchingCases.first.id, clerkId);
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FilingChatScreen(
                        filingId: caseId,
                        filingTitle: '$caseTitle (Clerk: $clerkName)',
                        currentUserRole: 'Lawyer',
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Icon(Icons.person, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.otherPersonName,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.isLawyer)
            IconButton(
              icon: const Icon(Icons.support_agent_outlined),
              tooltip: 'Chat with Assigned Clerk',
              onPressed: () => _openClerkChat(context),
            ),
        ],
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).primaryColor,
        elevation: 1,
      ),
      body: Consumer<RequestProvider>(
        builder: (context, requestProvider, child) {
          ConsultationRequest? foundRequest;
          for (var r in requestProvider.requests) {
            if (r.id == widget.requestId) {
              foundRequest = r;
              break;
            }
          }

          if (foundRequest == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final request = foundRequest;
          
          return Column(
            children: [
              if (widget.isLawyer && request.status != 'Case Started')
                Container(
                  width: double.infinity,
                  color: Colors.blue[50],
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('Ready to represent the client in court?', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.blue[800]))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                        onPressed: () => _showTakeCaseDialog(context, request),
                        child: const Text('Take Case'),
                      )
                    ],
                  ),
                ),
              if (request.status == 'Case Started')
                Container(
                  width: double.infinity,
                  color: Colors.green[50],
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.isLawyer 
                            ? 'Case Started' 
                            : 'Case officially taken by lawyer!', 
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.green[800], fontSize: 13),
                        ),
                      ),
                      if (widget.isLawyer) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF0D256C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          onPressed: () => _openClerkChat(context),
                          icon: const Icon(Icons.chat_outlined, size: 14),
                          label: const Text('Clerk Chat', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: request.messages.length + 1, // +1 for the initial issue description
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Initial issue description message (Always shown as from Citizen)
                      final isMe = !widget.isLawyer; 
                      return _buildMessageBubble(
                        context,
                        isMe: isMe,
                        message: 'Initial Issue: ${request.issueDescription}',
                        time: DateFormat('hh:mm a').format(request.requestedAt.toLocal()),
                      );
                    }
                    
                    final msg = request.messages[index - 1];
                    final isMe = (widget.isLawyer && msg['sender'] == 'Lawyer') || 
                                 (!widget.isLawyer && msg['sender'] == 'Citizen');
                                 
                    return _buildMessageBubble(
                      context,
                      isMe: isMe,
                      message: msg['text'],
                      time: msg['time'],
                    );
                  },
                ),
              ),
              _buildChatInput(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, {required bool isMe, required String message, required String time}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
          ),
          border: isMe ? null : Border.all(color: Colors.grey[300]!),
          boxShadow: isMe ? [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message == '[ENCRYPTED_FILE]')
              ElevatedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) {
                      return Container(
                        padding: const EdgeInsets.only(top: 16),
                        height: MediaQuery.of(context).size.height * 0.8,
                        child: Column(
                          children: [
                            Text('Encrypted Evidence', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                            const Divider(),
                            Expanded(child: SecureEvidenceViewer(caseId: widget.requestId)),
                          ],
                        ),
                      );
                    }
                  );
                },
                icon: const Icon(Icons.lock, size: 16),
                label: const Text('View Encrypted File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMe ? Colors.white : Theme.of(context).primaryColor,
                  foregroundColor: isMe ? Theme.of(context).primaryColor : Colors.white,
                ),
              )
            else
              Text(
                message,
                style: GoogleFonts.inter(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              time,
              style: GoogleFonts.inter(
                color: isMe ? Colors.white70 : Colors.grey[500],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.attach_file, color: Colors.grey[600]),
              onPressed: _uploadEncryptedFile,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


