import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

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
        return AlertDialog(
          title: Text('Review Lawyer Registration', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Name', lawyer['username'] ?? 'Unknown'),
                _buildDetailRow('Email', lawyer['email'] ?? 'N/A'),
                const Divider(height: 32),
                Text('Verification Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                // Display actual DB data or explicitly say 'Not Provided'
                _buildDetailRow('Enrollment Number', lawyer['enrollment_number']?.toString() ?? 'Not Provided'),
                _buildDetailRow('Year', lawyer['enrollment_year']?.toString() ?? 'Not Provided'),
                _buildDetailRow('District', lawyer['district']?.toString() ?? 'Not Provided'),
                const SizedBox(height: 16),
                Text('Uploaded Documents', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            String displayName = 'No document uploaded';
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
                                color: rawName != null ? Colors.blue[700] : Colors.grey, 
                                decoration: rawName != null ? TextDecoration.underline : TextDecoration.none
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          }
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.visibility, color: Colors.blue),
                        tooltip: 'View Document',
                        onPressed: () async {
                          final docName = lawyer['verification_document'];
                          if (docName != null) {
                            try {
                              // Use getPublicUrl because createSignedUrl fails if there is no SELECT RLS policy
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
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to open file. Please fully RESTART the app (not hot reload).')));
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e (Try fully restarting the app)')));
                                }
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate URL. Check Supabase permissions: $e')));
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No document uploaded')));
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.download, color: Colors.green),
                        tooltip: 'Download Document',
                        onPressed: () async {
                          final docName = lawyer['verification_document'];
                          if (docName != null) {
                            try {
                              final url = Supabase.instance.client.storage.from('documents').getPublicUrl(docName);
                              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not download file: $e')));
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
              child: const Text('Close'),
            ),
            if (lawyer['is_verified'] != false) 
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateLawyerStatus(lawyer['id'], false); // Reject/Suspend
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(lawyer['is_verified'] == true ? 'Suspend' : 'Reject'),
              ),
            if (lawyer['is_verified'] != true)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateLawyerStatus(lawyer['id'], true); // Approve
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Approve'),
              ),
          ],
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
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Verified'),
            Tab(text: 'Rejected'),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLawyerList(_allLawyers),
                    _buildLawyerList(_allLawyers.where((l) => l['is_verified'] == null).toList()),
                    _buildLawyerList(_allLawyers.where((l) => l['is_verified'] == true).toList()),
                    _buildLawyerList(_allLawyers.where((l) => l['is_verified'] == false).toList()),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildLawyerList(List<Map<String, dynamic>> lawyers) {
    if (lawyers.isEmpty) {
      return Center(
        child: Text(
          'No lawyers found.',
          style: GoogleFonts.inter(color: Colors.grey, fontSize: 16),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchLawyers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lawyers.length,
        itemBuilder: (context, index) {
          final lawyer = lawyers[index];
          final isVerified = lawyer['is_verified'] == true;
          final isRejected = lawyer['is_verified'] == false;
          final isPending = lawyer['is_verified'] == null;
          
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: isVerified ? Colors.green.withOpacity(0.1) : (isRejected ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1)),
                child: Icon(Icons.gavel, color: isVerified ? Colors.green : (isRejected ? Colors.red : Colors.orange)),
              ),
              title: Text(
                lawyer['username'] ?? 'Unknown Lawyer',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Text(
                'Status: ${isVerified ? "Verified" : (isRejected ? "Rejected/Suspended" : "Pending")}\nEmail: ${lawyer['email'] ?? 'N/A'}',
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
              isThreeLine: true,
              onTap: () => _showReviewDialog(lawyer),
              trailing: isVerified 
                ? ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _updateLawyerStatus(lawyer['id'], false),
                    child: const Text('Suspend'),
                  )
                : isPending 
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showReviewDialog(lawyer),
                      child: const Text('Review'),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _updateLawyerStatus(lawyer['id'], true),
                      child: const Text('Restore'),
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
