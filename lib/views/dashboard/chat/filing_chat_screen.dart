import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
// removed flutter_windowmanager import
import '../../../controllers/filing_chat_provider.dart';

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


