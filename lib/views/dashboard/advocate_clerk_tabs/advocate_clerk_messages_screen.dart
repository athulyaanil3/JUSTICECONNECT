import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../controllers/advocate_clerk_provider.dart';
import '../chat/filing_chat_screen.dart';

class AdvocateClerkMessagesScreen extends StatefulWidget {
  const AdvocateClerkMessagesScreen({Key? key}) : super(key: key);

  @override
  State<AdvocateClerkMessagesScreen> createState() => _AdvocateClerkMessagesScreenState();
}

class _AdvocateClerkMessagesScreenState extends State<AdvocateClerkMessagesScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdvocateClerkProvider>(context, listen: false).fetchAllData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final clerkId = user?.id ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Lawyer Chats & Messages',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D256C),
        elevation: 1,
      ),
      body: Consumer<AdvocateClerkProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final cases = provider.cases.where((c) {
            if (_searchQuery.isEmpty) return true;
            final query = _searchQuery.toLowerCase();
            return c.title.toLowerCase().contains(query) ||
                c.caseNumber.toLowerCase().contains(query) ||
                c.category.toLowerCase().contains(query);
          }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              await provider.fetchAllData();
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                // Search Field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim());
                      },
                      decoration: InputDecoration(
                        hintText: 'Search case chats...',
                        hintStyle: GoogleFonts.inter(color: Colors.grey[500], fontSize: 14),
                        prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),

                // Direct Office Chat with Lawyer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.work_outline, size: 18, color: Color(0xFF0D256C)),
                      const SizedBox(width: 8),
                      Text(
                        'Direct Office Channel',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF0D256C).withOpacity(0.1),
                    child: const Icon(Icons.account_balance, color: Color(0xFF0D256C), size: 26),
                  ),
                  title: Text(
                    'Direct Chat with Associated Lawyer',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Text(
                    'Office Communication & Direct Instructions',
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
                          filingTitle: 'Direct Office Chat with Lawyer',
                          currentUserRole: 'Advocate Clerk',
                        ),
                      ),
                    );
                  },
                ),

                const Divider(height: 24, indent: 16, endIndent: 16),

                // Case Chats Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.gavel, size: 18, color: Color(0xFF0D256C)),
                      const SizedBox(width: 8),
                      Text(
                        'Assigned Case Matters',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
                      ),
                      const Spacer(),
                      Text(
                        '${cases.length} cases',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                if (cases.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: Center(
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'No matching cases found.'
                            : 'No cases assigned yet.',
                        style: GoogleFonts.inter(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  )
                else
                  ...cases.map((c) {
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
                          child: const Icon(Icons.folder_shared, color: Colors.indigo, size: 22),
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
                          child: Text(
                            c.caseNumber.isNotEmpty ? 'Case No: ${c.caseNumber} • ${c.category}' : 'Category: ${c.category}',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ),
                        trailing: const Icon(Icons.chat_bubble_outline, color: Color(0xFF0D256C), size: 22),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FilingChatScreen(
                                filingId: c.id,
                                filingTitle: c.title,
                                currentUserRole: 'Advocate Clerk',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}
