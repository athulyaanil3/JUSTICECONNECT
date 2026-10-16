import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../controllers/request_provider.dart';
import '../../../controllers/lawyer_provider.dart';
import '../../../models/legal_case.dart';
import '../chat/chat_screen.dart';
import 'chat/filing_chat_screen.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({Key? key}) : super(key: key);

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  TabController? _tabController;
  List<Map<String, dynamic>> _officeClerks = [];
  bool _isLoadingClerks = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RequestProvider>(context, listen: false).fetchRequests();
      final user = Supabase.instance.client.auth.currentUser;
      final role = user?.userMetadata?['role'] ?? 'Citizen';
      if (role == 'Lawyer') {
        Provider.of<LawyerProvider>(context, listen: false).fetchMyCases();
        _loadOfficeClerks();
      }
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadOfficeClerks() async {
    final user = Supabase.instance.client.auth.currentUser;
    final role = user?.userMetadata?['role'] ?? 'Citizen';
    if (role != 'Lawyer') return;

    setState(() {
      _isLoadingClerks = true;
    });

    try {
      final lawyerProvider = Provider.of<LawyerProvider>(context, listen: false);
      final clerks = await lawyerProvider.fetchAvailableClerks();
      if (mounted) {
        setState(() {
          _officeClerks = clerks;
          _isLoadingClerks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingClerks = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final role = user?.userMetadata?['role'] ?? 'Citizen';
    final isLawyer = role == 'Lawyer';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Container(
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: isLawyer ? 'Search clients, clerks or cases' : 'Search messages',
              hintStyle: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
              prefixIcon: Icon(Icons.search, color: const Color(0xFF0D256C), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        bottom: isLawyer
            ? TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF0D256C),
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: const Color(0xFF0D256C),
                indicatorWeight: 3,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 13),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.people_outline, size: 20),
                    text: 'Clients',
                  ),
                  Tab(
                    icon: Icon(Icons.support_agent_outlined, size: 20),
                    text: 'Assigned Clerks',
                  ),
                ],
              )
            : null,
      ),
      body: isLawyer
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildClientsList(context, isLawyer),
                Consumer<LawyerProvider>(
                  builder: (context, lawyerProvider, child) {
                    return _buildClerksTab(context, lawyerProvider);
                  },
                ),
              ],
            )
          : _buildClientsList(context, isLawyer),
    );
  }

  Widget _buildClientsList(BuildContext context, bool isLawyer) {
    return Consumer<RequestProvider>(
      builder: (context, provider, child) {
        // Group requests by the other person's name to ensure a standard chat experience (1 row per person)
        Map<String, dynamic> groupedChats = {};
        for (var r in provider.requests) {
          if (r.status == 'Accepted' || r.status == 'Confirmed' || r.status == 'Case Started' || r.messages.isNotEmpty) {
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
            final nameMatches = otherPersonName.toLowerCase().contains(_searchQuery);

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
          return RefreshIndicator(
            onRefresh: () async {
              await Provider.of<RequestProvider>(context, listen: false).fetchRequests();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                Center(
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? 'No messages found.'
                        : 'No active conversations yet.',
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 16),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await Provider.of<RequestProvider>(context, listen: false).fetchRequests();
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
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
              // If no messages, show the request date/time in local format
              lastMessageTime = DateFormat('hh:mm a').format(request.requestedAt.toLocal());
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
        ),
      );
    },
  );
}

  Widget _buildClerksTab(BuildContext context, LawyerProvider lawyerProvider) {
    final query = _searchQuery.trim().toLowerCase();

    // 1. Filter office clerks
    final filteredClerks = _officeClerks.where((clerk) {
      if (query.isEmpty) return true;
      final name = (clerk['username'] ?? '').toString().toLowerCase();
      return name.contains(query);
    }).toList();

    // 2. Filter cases that have an assigned clerk
    final casesWithClerk = lawyerProvider.myCases.where((c) => c.advocateClerkId.isNotEmpty).toList();
    final filteredCasesWithClerk = casesWithClerk.where((c) {
      if (query.isEmpty) return true;
      final title = c.title.toLowerCase();
      final caseNo = c.caseNumber.toLowerCase();
      final category = c.category.toLowerCase();
      final matchingClerk = _officeClerks.firstWhere(
        (cl) => cl['id'] == c.advocateClerkId,
        orElse: () => {},
      );
      final clerkName = (matchingClerk['username'] ?? '').toString().toLowerCase();
      return title.contains(query) || caseNo.contains(query) || category.contains(query) || clerkName.contains(query);
    }).toList();

    // 3. Filter cases without clerk
    final unassignedCases = lawyerProvider.myCases.where((c) => c.advocateClerkId.isEmpty).toList();
    final filteredUnassigned = unassignedCases.where((c) {
      if (query.isEmpty) return true;
      return c.title.toLowerCase().contains(query) || c.caseNumber.toLowerCase().contains(query);
    }).toList();

    if (_isLoadingClerks && lawyerProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_officeClerks.isEmpty && casesWithClerk.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await _loadOfficeClerks();
          await lawyerProvider.fetchMyCases();
        },
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 60),
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D256C).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.support_agent, size: 54, color: Color(0xFF0D256C)),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'No Assigned Clerks Found',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'When advocate clerks are registered under your office or assigned to your legal cases, secure chat channels will appear here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadOfficeClerks();
        await lawyerProvider.fetchMyCases();
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Section A: Office Advocate Clerks
          if (filteredClerks.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, size: 18, color: Color(0xFF0D256C)),
                  const SizedBox(width: 8),
                  Text(
                    'Office Advocate Clerks',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
                  ),
                ],
              ),
            ),
            ...filteredClerks.map((clerk) {
              final clerkId = clerk['id'] as String;
              final clerkName = (clerk['username'] ?? 'Advocate Clerk').toString();

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF0D256C).withOpacity(0.1),
                  child: const Icon(Icons.support_agent, color: Color(0xFF0D256C), size: 28),
                ),
                title: Text(
                  clerkName,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  'Office Advocate Clerk • Direct Secure Chat',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D256C),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Chat',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FilingChatScreen(
                        filingId: 'clerk_direct_$clerkId',
                        filingTitle: '$clerkName (Advocate Clerk)',
                        currentUserRole: 'Lawyer',
                      ),
                    ),
                  );
                },
              );
            }),
            const Divider(height: 24, indent: 16, endIndent: 16),
          ],

          // Section B: Case Coordination Threads
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.folder_shared_outlined, size: 18, color: Color(0xFF0D256C)),
                const SizedBox(width: 8),
                Text(
                  'Case Matters with Assigned Clerks',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
                ),
                const Spacer(),
                Text(
                  '${filteredCasesWithClerk.length} cases',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          if (filteredCasesWithClerk.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                query.isNotEmpty
                    ? 'No matching cases found.'
                    : 'No cases have been assigned to clerks yet.',
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
              ),
            )
          else
            ...filteredCasesWithClerk.map((c) {
              final matchingClerk = _officeClerks.firstWhere(
                (cl) => cl['id'] == c.advocateClerkId,
                orElse: () => {'username': 'Assigned Clerk'},
              );
              final clerkName = matchingClerk['username'] ?? 'Assigned Clerk';

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.indigo.withOpacity(0.1),
                    child: const Icon(Icons.gavel, color: Colors.indigo, size: 22),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.title,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          c.status,
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green[800]),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Clerk: $clerkName',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                        ),
                        if (c.caseNumber.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '•  ${c.caseNumber}',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chat_bubble_outline, color: Color(0xFF0D256C), size: 22),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FilingChatScreen(
                          filingId: c.id,
                          filingTitle: '${c.title} (Clerk: $clerkName)',
                          currentUserRole: 'Lawyer',
                        ),
                      ),
                    );
                  },
                ),
              );
            }),

          // Section C: Unassigned Cases that can be assigned to a clerk
          if (filteredUnassigned.isNotEmpty && _officeClerks.isNotEmpty) ...[
            const Divider(height: 28, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.person_add_alt_outlined, size: 18, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Assign Clerk to Case',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange[900]),
                  ),
                ],
              ),
            ),
            ...filteredUnassigned.map((c) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: ListTile(
                  dense: true,
                  title: Text(c.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('Status: ${c.status} • Category: ${c.category}', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                  trailing: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0D256C),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Assign & Chat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _assignClerkToCase(context, c, lawyerProvider),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _assignClerkToCase(BuildContext context, LegalCase c, LawyerProvider lawyerProvider) {
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
                  'Assign Advocate Clerk',
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select an advocate clerk to coordinate on "${c.title}":',
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
            ),
            const Divider(height: 24),
            if (_officeClerks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No verified clerks available in your office.', style: GoogleFonts.inter(color: Colors.grey)),
              )
            else
              ..._officeClerks.map((clerk) {
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
                  trailing: const Icon(Icons.check_circle_outline, color: Color(0xFF0D256C)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await lawyerProvider.assignAdvocateClerk(c.id, clerkId);
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FilingChatScreen(
                            filingId: c.id,
                            filingTitle: '${c.title} (Clerk: $clerkName)',
                            currentUserRole: 'Lawyer',
                          ),
                        ),
                      );
                    }
                  },
                );
              }),
          ],
        ),
      ),
    );
  }
}
