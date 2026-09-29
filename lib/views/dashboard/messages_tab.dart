import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../controllers/request_provider.dart';
import '../chat/chat_screen.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({Key? key}) : super(key: key);

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  String _searchQuery = '';

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
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search messages',
              hintStyle: GoogleFonts.inter(color: Colors.grey[600]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: Consumer<RequestProvider>(
        builder: (context, provider, child) {
          // Group requests by the other person's name to ensure a standard chat experience (1 row per person)
          Map<String, dynamic> groupedChats = {};
          for (var r in provider.requests) {
            if (r.status == 'Accepted' || r.status == 'Confirmed' || r.messages.isNotEmpty) {
              final otherPersonName = isLawyer ? r.citizenName : r.lawyerName;
              if (!groupedChats.containsKey(otherPersonName)) {
                groupedChats[otherPersonName] = r;
              } else {
                // If there's already a chat with this person, keep the one with the most recent activity (messages)
                final existingReq = groupedChats[otherPersonName];
                if (r.messages.isNotEmpty && existingReq.messages.isEmpty) {
                  groupedChats[otherPersonName] = r;
                } else if (r.messages.isNotEmpty && existingReq.messages.isNotEmpty) {
                  groupedChats[otherPersonName] = r; // Overwrite with latest request's chat
                }
              }
            }
          }
          var activeChats = groupedChats.values.toList();

          // Apply search filter
          if (_searchQuery.isNotEmpty) {
            activeChats = activeChats.where((r) {
              final otherPersonName = isLawyer ? r.citizenName : r.lawyerName;
              final nameMatches = otherPersonName.toLowerCase().contains(
                _searchQuery,
              );

              // Also search last message content
              bool messageMatches = false;
              if (r.messages.isNotEmpty) {
                final lastMsg = r.messages.last;
                messageMatches = (lastMsg['text'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery);
              }

              return nameMatches || messageMatches;
            }).toList();
          }

          if (activeChats.isEmpty) {
            return Center(
              child: Text(
                _searchQuery.isNotEmpty
                    ? 'No messages found.'
                    : 'No active conversations yet.',
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.separated(
            itemCount: activeChats.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final request = activeChats[index];
              final otherPersonName = isLawyer
                  ? request.citizenName
                  : request.lawyerName;

              // Get the last message if available
              String lastMessageText = 'Start a conversation';
              String lastMessageTime = '';

              if (request.messages.isNotEmpty) {
                final lastMsg = request.messages.last;
                final bool isMe =
                    lastMsg['sender'] == (isLawyer ? 'Lawyer' : 'Citizen');
                lastMessageText = isMe ? 'You: ' : '';
                lastMessageTime = lastMsg['time'] ?? '';
              } else {
                // If no messages, just show the request date/time
                lastMessageTime = '\/';
              }

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).primaryColor,
                    size: 32,
                  ),
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
