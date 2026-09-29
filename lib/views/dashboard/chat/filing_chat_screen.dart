import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
// removed flutter_windowmanager import
import '../../../controllers/filing_chat_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/evidence_encryption_service.dart';
import '../../../services/pattern_verification_service.dart';
import '../../shared/secure_evidence_viewer.dart';

class FilingChatScreen extends StatefulWidget {
  final String filingId;
  final String filingTitle;
  final String currentUserRole; // 'Lawyer' or 'Advocate Clerk'

  const FilingChatScreen({
    Key? key,
    required this.filingId,
    required this.filingTitle,
    required this.currentUserRole,
  }) : super(key: key);

  @override
  _FilingChatScreenState createState() => _FilingChatScreenState();
}

class _FilingChatScreenState extends State<FilingChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _secureScreen();
    // Use Future.microtask to load chat without blocking initial render
    Future.microtask(() {
      Provider.of<FilingChatProvider>(context, listen: false)
          .loadChatForFiling(widget.filingId);
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
    Provider.of<FilingChatProvider>(context, listen: false)
        .sendMessage(_messageController.text, widget.currentUserRole);
    _messageController.clear();
    // Scroll to bottom
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _uploadEncryptedFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'mp4'],
      );

      if (result == null || result.isEmpty) return;
      
      final files = result.map((f) => File(f.path!)).toList();
      
      num totalSize = 0;
      for (var f in files) {
        totalSize += await f.length();
      }
      if (totalSize > 50 * 1024 * 1024) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Total file size must not exceed 50MB.')));
        return;
      }

      // 🔐 Pattern Verification Before Sending 🔐
      final isAuthenticated = await PatternVerificationService.authenticate(
        context: context,
        reason: 'Please draw your pattern to authorize this secure evidence transfer.',
        userKey: Supabase.instance.client.auth.currentUser?.email,
      );

      if (!isAuthenticated) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication failed. File not sent.')));
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
      final storagePath = '${widget.filingId}/$documentId.enc';
      final supabase = Supabase.instance.client;

      // Upload encrypted file
      await supabase.storage.from('case-evidence').upload(storagePath, encryptionResult.encryptedFile);

      // Insert metadata
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('case_documents').insert({
        'id': documentId,
        'case_id': widget.filingId,
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
      Provider.of<FilingChatProvider>(context, listen: false)
          .sendMessage('[ENCRYPTED_FILE]', widget.currentUserRole);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chat', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(widget.filingTitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[300])),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<FilingChatProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.messages.length,
                  itemBuilder: (context, index) {
                    final message = provider.messages[index];
                    final bool isMe = message['sender_role'] == widget.currentUserRole;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? Theme.of(context).primaryColor : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: isMe ? null : Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(
                                message['sender_role'] ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            const SizedBox(height: 2),
                            if (message['text'] == '[ENCRYPTED_FILE]')
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
                                            Text('Case Evidence: ${widget.filingTitle}', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                                            const Divider(),
                                            Expanded(child: SecureEvidenceViewer(caseId: widget.filingId)),
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
                                message['text'] ?? '',
                                style: GoogleFonts.inter(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 5,
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
                  hintStyle: GoogleFonts.inter(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


