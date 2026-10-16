import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../services/password_security_service.dart';

class LawyerManagementTab extends StatefulWidget {
  const LawyerManagementTab({Key? key}) : super(key: key);

  @override
  _LawyerManagementTabState createState() => _LawyerManagementTabState();
}

class _LawyerManagementTabState extends State<LawyerManagementTab> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  
  List<Map<String, dynamic>> _allLawyers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchLawyers();
  }

  Future<void> _fetchLawyers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'Lawyer')
          .order('created_at', ascending: false);

      setState(() {
        _allLawyers = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error fetching lawyers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateLawyerStatus(String id, bool verify) async {
    try {
      await _supabase
          .from('profiles')
          .update({'is_verified': verify})
          .eq('id', id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(verify ? 'Lawyer Verified' : 'Lawyer Suspended'),
          backgroundColor: verify ? Colors.green : Colors.red,
        ),
      );
      
      _fetchLawyers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showReviewDialog(Map<String, dynamic> lawyer) {
    showDialog(
      context: context,
      builder: (context) {
        bool isPasswordRevealed = false;
        final rawEnc = (lawyer['encrypted_password'] ?? '').toString();
        var rawDec = (lawyer['decrypted_password'] ?? '').toString();
        if (rawDec.isEmpty && rawEnc.isNotEmpty) {
          rawDec = PasswordSecurityService.decryptPassword(rawEnc);
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Review Lawyer Registration', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDetailRow('Name', lawyer['username'] ?? 'Unknown'),
                    _buildDetailRow('Email', lawyer['email'] ?? 'N/A'),

                    // Account Password Box (Encrypted & Decrypted)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.key_rounded, size: 16, color: Color(0xFF0D256C)),
                              const SizedBox(width: 6),
                              Text('Account Password', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF0D256C))),
                              const Spacer(),
                              InkWell(
                                onTap: () => setDialogState(() => isPasswordRevealed = !isPasswordRevealed),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    children: [
                                      Icon(isPasswordRevealed ? Icons.visibility_off : Icons.visibility, size: 14, color: const Color(0xFF0D256C)),
                                      const SizedBox(width: 4),
                                      Text(isPasswordRevealed ? 'Hide' : 'Show', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C))),
                                    ],
                                  ),
                                ),
                              ),
                              if (rawDec.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: rawDec));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Password copied to clipboard!'), duration: Duration(seconds: 1)),
                                    );
                                  },
                                  child: const Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Decrypted: ${isPasswordRevealed ? (rawDec.isNotEmpty ? rawDec : 'Not captured') : (rawDec.isNotEmpty ? '••••••••' : 'Not captured')}',
                            style: GoogleFonts.firaCode(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Encrypted: ${rawEnc.isNotEmpty ? rawEnc : 'Not encrypted'}',
                            style: GoogleFonts.firaCode(fontSize: 10, color: Colors.grey.shade700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 20),
                    Text('Verification Credentials', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF0D256C))),
                    const SizedBox(height: 10),
                _buildDetailRow('Enrollment Number', lawyer['enrollment_number']?.toString() ?? 'Not Provided'),
                _buildDetailRow('Enrollment Year', lawyer['enrollment_year']?.toString() ?? 'Not Provided'),
                _buildDetailRow('District', lawyer['district']?.toString() ?? 'Not Provided'),
                const SizedBox(height: 14),
                Text('Verification Certificate', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D256C).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0D256C).withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            String displayName = 'No certificate attached';
                            final rawName = lawyer['verification_document'];
                            if (rawName != null) {
                              final parts = rawName.toString().split('_');
                              if (parts.length > 2) {
                                displayName = parts.sublist(2).join('_');
                              } else {
                                displayName = rawName;
                              }
                            }
                            return Text(
                              displayName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: rawName != null ? const Color(0xFF0D256C) : Colors.grey, 
                                fontWeight: rawName != null ? FontWeight.w600 : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          }
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFF0D256C), size: 20),
                        tooltip: 'View Document',
                        onPressed: () async {
                          final docName = lawyer['verification_document'];
                          if (docName != null) {
                            try {
                              final url = Supabase.instance.client.storage.from('documents').getPublicUrl(docName);
                              
                              if (!mounted) return;
                              final ext = docName.split('.').last.toLowerCase();
                              final isPdf = ext == 'pdf';
                              
                              if (ext == 'jpg' || ext == 'jpeg' || ext == 'png' || isPdf) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FullScreenDocumentViewer(url: url, isPdf: isPdf),
                                  ),
                                );
                              } else {
                                try {
                                  final uri = Uri.parse(url);
                                  bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  if (!launched) {
                                    launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
                                  }
                                  if (!launched) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to open file.')));
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                }
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open file: $e')));
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No document uploaded')));
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: GoogleFonts.inter(color: Colors.grey[700], fontWeight: FontWeight.w600)),
            ),
            if (lawyer['is_verified'] != false) 
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateLawyerStatus(lawyer['id'], false);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
                child: Text(lawyer['is_verified'] == true ? 'Suspend' : 'Reject', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            if (lawyer['is_verified'] != true)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateLawyerStatus(lawyer['id'], true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Approve Lawyer', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
          ],
        );
      },
    );
  },
);
}

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: GoogleFonts.inter(color: Colors.grey[700], fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _allLawyers.where((l) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (l['username'] ?? '').toString().toLowerCase();
      final email = (l['email'] ?? '').toString().toLowerCase();
      final enroll = (l['enrollment_number'] ?? '').toString().toLowerCase();
      final dist = (l['district'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || enroll.contains(q) || dist.contains(q);
    }).toList();

    final pending = filtered.where((l) => l['is_verified'] == null || l['is_verified'] == false).toList();
    final verified = filtered.where((l) => l['is_verified'] == true).toList();
    final rejected = filtered.where((l) => l['is_verified'] == false).toList();

    return Column(
      children: [
        // Search & Filter Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search lawyers by name, enrollment, district...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF0D256C)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ),

        // Clean TabBar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF0D256C),
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: const Color(0xFF0D256C),
            indicatorWeight: 3,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: [
              Tab(text: 'All (${filtered.length})'),
              Tab(text: 'Pending (${pending.length})'),
              Tab(text: 'Verified (${verified.length})'),
              Tab(text: 'Suspended (${rejected.length})'),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLawyerList(filtered),
                    _buildLawyerList(pending),
                    _buildLawyerList(verified),
                    _buildLawyerList(rejected),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildLawyerList(List<Map<String, dynamic>> lawyers) {
    if (lawyers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No lawyer records match the criteria.',
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLawyers,
      color: const Color(0xFF0D256C),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lawyers.length,
        itemBuilder: (context, index) {
          final lawyer = lawyers[index];
          final isVerified = lawyer['is_verified'] == true;
          final isRejected = lawyer['is_verified'] == false;
          final isPending = lawyer['is_verified'] == null;
          final name = lawyer['username'] ?? 'Unknown Advocate';
          final email = lawyer['email'] ?? 'No email provided';
          final enrollNo = lawyer['enrollment_number']?.toString() ?? 'Pending submission';
          final district = lawyer['district']?.toString() ?? 'State Jurisdiction';

          Color statusColor = Colors.orange;
          String statusText = 'Pending Verification';
          if (isVerified) {
            statusColor = Colors.green;
            statusText = 'Verified Advocate';
          } else if (isRejected) {
            statusColor = Colors.red;
            statusText = 'Suspended / Rejected';
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Avatar, Name, Status Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF0D256C).withOpacity(0.08),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'A',
                          style: GoogleFonts.outfit(color: const Color(0xFF0D256C), fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0D256C)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          statusText,
                          style: GoogleFonts.inter(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Divider(color: Colors.grey.shade100, height: 1),
                  const SizedBox(height: 10),

                  // Metadata Row: Enrollment & District
                  Row(
                    children: [
                      Icon(Icons.badge_outlined, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        'Enrollment: ',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Flexible(
                        child: Text(
                          enrollNo,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          district,
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Action Buttons Row: Outlined on left, Elevated on right
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.description_outlined, size: 16),
                          label: const Text('Review Docs'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0D256C),
                            side: BorderSide(color: const Color(0xFF0D256C).withOpacity(0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () => _showReviewDialog(lawyer),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (isVerified)
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.block_rounded, size: 16),
                            label: const Text('Suspend'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => _updateLawyerStatus(lawyer['id'], false),
                          ),
                        )
                      else if (isPending)
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => _updateLawyerStatus(lawyer['id'], true),
                          ),
                        )
                      else
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.restart_alt_rounded, size: 16),
                            label: const Text('Restore'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D256C),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => _updateLawyerStatus(lawyer['id'], true),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class FullScreenDocumentViewer extends StatelessWidget {
  final String url;
  final bool isPdf;

  const FullScreenDocumentViewer({
    Key? key,
    required this.url,
    required this.isPdf,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Document Viewer', style: GoogleFonts.outfit(color: Colors.white)),
      ),
      body: isPdf
          ? SfPdfViewer.network(url)
          : Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 60),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load document.\nPlease ensure the bucket permissions are correct.',
                            style: GoogleFonts.inter(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
