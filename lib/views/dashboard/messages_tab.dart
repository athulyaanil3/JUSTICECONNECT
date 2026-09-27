import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../controllers/request_provider.dart';
import '../chat/chat_screen.dart';

class MessagesTab extends StatelessWidget {
  const MessagesTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final role = user?.userMetadata?['role'] ?? 'Citizen';
    final isLawyer = role == 'Lawyer';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search messages',
              hintStyle: GoogleFonts.inter(color: Colors.grey[600]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.grey[800]),
            onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature available in full version'))); },
          ),
        ],
      ),
      body: Consumer<RequestProvider>(
        builder: (context, provider, child) {
          // Filter for only accepted or confirmed requests
          final activeChats = provider.requests.where((r) => r.status == 'Accepted' || r.status == 'Confirmed').toList();

          if (activeChats.isEmpty) {
            return Center(
              child: Text(
                'No active conversations yet.',
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.separated(
            itemCount: activeChats.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final request = activeChats[index];
              final otherPersonName = isLawyer ? request.citizenName : request.lawyerName;
              
              // Get the last message if available
              String lastMessageText = 'Start a conversation';
              String lastMessageTime = '';
              
              if (request.messages.isNotEmpty) {
                final lastMsg = request.messages.last;
                final bool isMe = lastMsg['sender'] == (isLawyer ? 'Lawyer' : 'Citizen');
                lastMessageText = isMe ? 'You: ${lastMsg['text']}' : '${lastMsg['text']}';
                lastMessageTime = lastMsg['time'] ?? '';
              } else {
                // If no messages, just show the request date/time
                lastMessageTime = '${request.requestedAt.day}/${request.requestedAt.month}';
              }

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Icon(Icons.person, color: Theme.of(context).primaryColor, size: 32),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        otherPersonName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      lastMessageTime,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    lastMessageText,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        requestId: request.id,
                        otherPersonName: otherPersonName,
                        isLawyer: isLawyer,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
