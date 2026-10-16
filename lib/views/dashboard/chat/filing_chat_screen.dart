import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../controllers/filing_chat_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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
    Future.microtask(() {
      Provider.of<FilingChatProvider>(context, listen: false)
          .loadChatForFiling(widget.filingId);
    });
  }

  @override
  void dispose() {
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

  Future<void> _uploadFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx', 'doc', 'txt', 'mp4'],
      );

      if (result.isEmpty || result.first.path == null) return;
      
      final file = File(result.first.path!);
      final fileName = result.first.name;
      final fileSize = await file.length();
      
      if (fileSize > 50 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File size must not exceed 50MB.')),
          );
        }
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
              Text('Sending file...'),
            ],
          ),
        ),
      );

      final supabase = Supabase.instance.client;
      final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath = 'filing_chats/${widget.filingId}/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';

      // Direct upload in unencrypted format
      await supabase.storage.from('documents').upload(
        storagePath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      final fileUrl = supabase.storage.from('documents').getPublicUrl(storagePath);

      if (mounted) Navigator.pop(context); // Close loading dialog

      // Send chat message with file name and direct URL
      Provider.of<FilingChatProvider>(context, listen: false)
          .sendMessage('[FILE]:$fileName|$fileUrl', widget.currentUserRole);

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      debugPrint('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Widget _buildFileCard(String messageText, bool isMe) {
    final content = messageText.substring(7);
    final parts = content.split('|');
    final fileName = parts.first;
    final fileUrl = parts.length > 1 ? parts[1] : '';

    final lower = fileName.toLowerCase();
    final isPdf = lower.endsWith('.pdf');
    final isImg = lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png');

    return InkWell(
      onTap: () async {
        if (fileUrl.isNotEmpty) {
          final uri = Uri.parse(fileUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not open file URL')),
              );
            }
          }
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.18) : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe ? Colors.white30 : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isMe ? Colors.white : const Color(0xFF0D256C),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                isPdf
                    ? Icons.picture_as_pdf
                    : (isImg ? Icons.image : Icons.insert_drive_file),
                size: 20,
                color: isMe ? const Color(0xFF0D256C) : Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to view / download',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isMe ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.open_in_new,
              size: 16,
              color: isMe ? Colors.white70 : Colors.grey[700],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.currentUserRole == 'Lawyer' ? 'Clerk Chat' : 'Lawyer Chat',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              widget.filingTitle, 
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0D256C),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<FilingChatProvider>(
              builder: (context, chatProvider, child) {
                if (chatProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (chatProvider.messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Send a message to coordinate.',
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: chatProvider.messages.length,
                  itemBuilder: (context, index) {
                    final message = chatProvider.messages[index];
                    final isMe = message['sender_role'] == widget.currentUserRole;
                    final msgText = (message['text'] ?? '').toString();
                    final isFile = msgText.startsWith('[FILE]:');
                    final isLegacyEncrypted = msgText == '[ENCRYPTED_FILE]';

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: EdgeInsets.symmetric(
                          horizontal: isFile ? 4 : 14,
                          vertical: isFile ? 4 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? Theme.of(context).primaryColor : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
                            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Padding(
                                padding: EdgeInsets.only(left: isFile ? 8 : 0, bottom: 2, top: isFile ? 4 : 0),
                                child: Text(
                                  message['sender_role'] ?? 'Office',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (isFile)
                              _buildFileCard(msgText, isMe)
                            else if (isLegacyEncrypted)
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
                                msgText,
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
              tooltip: 'Attach File',
              onPressed: _uploadFile,
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
