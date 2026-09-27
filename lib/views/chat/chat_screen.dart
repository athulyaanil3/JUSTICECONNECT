import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
// removed flutter_windowmanager import

import '../../controllers/request_provider.dart';
import '../../controllers/lawyer_provider.dart';
import '../../controllers/notification_provider.dart';
import '../../models/consultation_request.dart';
import '../../models/app_notification.dart';
import 'package:uuid/uuid.dart';

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
      'time': 'Just now',
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
            Text(
              widget.otherPersonName,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).primaryColor,
        elevation: 1,
      ),
      body: Consumer<RequestProvider>(
        builder: (context, requestProvider, child) {
          final request = requestProvider.requests.firstWhere((r) => r.id == widget.requestId);
          
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(widget.isLawyer ? 'Case Started. Manage case details in Case Management tab.' : 'Case officially taken by lawyer!', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.green[800]))),
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
                        time: 'At requested time',
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
              onPressed: () { 
                showModalBottomSheet(
                  context: context,
                  builder: (context) {
                    return SafeArea(
                      child: Wrap(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                            title: const Text('Upload PDF Document'),
                            onTap: () {
                              Navigator.pop(context);
                              _messageController.text = '[Document] case_details.pdf';
                              _sendMessage();
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.image, color: Colors.blue),
                            title: const Text('Upload Image'),
                            onTap: () {
                              Navigator.pop(context);
                              _messageController.text = '[Image] evidence_photo.jpg';
                              _sendMessage();
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.camera_alt, color: Colors.green),
                            title: const Text('Take a Photo'),
                            onTap: () {
                              Navigator.pop(context);
                              _messageController.text = '[Photo] IMG_20260926.jpg';
                              _sendMessage();
                            },
                          ),
                        ],
                      ),
                    );
                  }
                );
              },
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


