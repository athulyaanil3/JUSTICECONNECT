import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../controllers/request_provider.dart';
import '../../../models/consultation_request.dart';
import 'lawyer_public_profile_screen.dart';
import 'office_search_view.dart';

class LawyerSearchTab extends StatefulWidget {
  final VoidCallback? onBookingSuccess;
  const LawyerSearchTab({Key? key, this.onBookingSuccess}) : super(key: key);

  @override
  _LawyerSearchTabState createState() => _LawyerSearchTabState();
}

class _LawyerSearchTabState extends State<LawyerSearchTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allLawyers = [];
  List<Map<String, dynamic>> _filteredLawyers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'rating';

  @override
  void initState() {
    super.initState();
    _fetchLawyers();
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_allLawyers);

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((lawyer) {
        final name = (lawyer['username'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (_sortBy == 'rating') {
      filtered.sort((a, b) {
        final ratingA = (a['rating'] ?? 0).toDouble();
        final ratingB = (b['rating'] ?? 0).toDouble();
        return ratingB.compareTo(ratingA); // Descending
      });
    } else if (_sortBy == 'name') {
      filtered.sort((a, b) {
        final nameA = (a['username'] ?? '').toString().toLowerCase();
        final nameB = (b['username'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB); // Ascending
      });
    }

    setState(() {
      _filteredLawyers = filtered;
    });
  }

  Future<void> _fetchLawyers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'Lawyer')
          .eq('is_verified', true)
          .order('rating', ascending: false)
          .order('username', ascending: true);

      setState(() {
        _allLawyers = List<Map<String, dynamic>>.from(response);
        _applyFilters();
      });
    } catch (e) {
      debugPrint('Error fetching verified lawyers: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(
            'Find a Lawyer',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Theme.of(context).primaryColor,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterDialog,
            ),
          ],
          bottom: TabBar(
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(text: 'Lawyers'),
              Tab(text: 'Offices'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Lawyers
            Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: TextField(
                    onChanged: (value) {
                      _searchQuery = value;
                      _applyFilters();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by name...',
                      hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredLawyers.isEmpty
                          ? Center(
                              child: Text(
                                'No verified lawyers found matching your criteria.',
                                style: GoogleFonts.inter(color: Colors.grey, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: _filteredLawyers.length,
                              itemBuilder: (context, index) {
                                return _buildLawyerCard(context, _filteredLawyers[index]);
                              },
                            ),
                ),
              ],
            ),
            // Tab 2: Offices
            OfficeSearchView(onBookingSuccess: widget.onBookingSuccess),
          ],
        ),
      ),
    );
  }

  Widget _buildLawyerCard(BuildContext context, Map<String, dynamic> lawyer) {
    final name = lawyer['username'] ?? 'Unknown Lawyer';
    final spec = 'General Practice'; // Hardcoded for now since spec isn't in profiles
    
    final requestProvider = Provider.of<RequestProvider>(context);
    final alreadyBooked = requestProvider.requests.any((req) =>
        req.lawyerName.toLowerCase() == name.toLowerCase() && 
        req.status != 'Rejected' && 
        req.status != 'Closed' && 
        req.status != 'Completed' && 
        req.status != 'Resolved');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: 'avatar_${name}',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: const Icon(Icons.person, size: 40, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        spec,
                        style: GoogleFonts.inter(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber[200]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.amber[600]),
                            const SizedBox(width: 4),
                            Text(
                              "${lawyer['rating'] ?? 'New'} (${lawyer['rating_count'] ?? 0})",
                              style: GoogleFonts.inter(
                                color: Colors.amber[900],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final shouldBook = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LawyerPublicProfileScreen(lawyer: lawyer),
                        ),
                      );
                      
                      if (shouldBook == true && mounted) {
                        _checkAndShowBookingDialog(context, name);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                      side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.3), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('View Profile', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: alreadyBooked ? null : () => _checkAndShowBookingDialog(context, name),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: alreadyBooked ? Colors.grey[200] : Theme.of(context).colorScheme.secondary,
                      foregroundColor: alreadyBooked ? Colors.grey[500] : Colors.black87,
                      elevation: alreadyBooked ? 0 : 2,
                      shadowColor: Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(alreadyBooked ? 'Requested' : 'Send Request', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _checkAndShowBookingDialog(BuildContext context, String lawyerName) {
    final user = Supabase.instance.client.auth.currentUser;
    final citizenUsername = user?.userMetadata?['username'] ?? 'Citizen';
    final requestProvider = Provider.of<RequestProvider>(context, listen: false);

    final alreadyBooked = requestProvider.requests.any((req) =>
        req.lawyerName.toLowerCase() == lawyerName.toLowerCase() && 
        req.status != 'Rejected' && 
        req.status != 'Closed' && 
        req.status != 'Completed' && 
        req.status != 'Resolved');

    if (alreadyBooked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already sent a request to this lawyer.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _showBookingDialog(context, lawyerName);
  }

  void _showBookingDialog(BuildContext context, String lawyerName) {
    final issueController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Request Consultation with $lawyerName', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: issueController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Briefly describe your legal issue...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                  onPressed: () {
                    if (issueController.text.trim().isEmpty) return;

                    final alreadyBooked = Provider.of<RequestProvider>(context, listen: false)
                        .requests.any((req) => req.lawyerName.toLowerCase() == lawyerName.toLowerCase() && 
                                              req.status != 'Rejected' && 
                                              req.status != 'Closed' && 
                                              req.status != 'Completed' && 
                                              req.status != 'Resolved');
                    
                    if (alreadyBooked) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already sent a request to this lawyer.'), backgroundColor: Colors.orange));
                      return;
                    }

                    final user = Supabase.instance.client.auth.currentUser;
                    final citizenUsername = user?.userMetadata?['username'] ?? 'Citizen';

                    final request = ConsultationRequest(
                      id: Uuid().v4(),
                      citizenName: citizenUsername,
                      lawyerName: lawyerName,
                      issueDescription: issueController.text.trim(),
                      requestedAt: DateTime.now(),
                    );

                    Provider.of<RequestProvider>(context, listen: false).addRequest(request);
                    
                    Navigator.pop(context); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request Sent Successfully!'), backgroundColor: Colors.green));
                    
                    if (widget.onBookingSuccess != null) {
                      widget.onBookingSuccess!();
                    }
                  },
                  child: const Text('Send Request'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }


  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sort & Filter', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text('Sort By', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              RadioListTile<String>(
                title: const Text('Rating (Highest First)'),
                value: 'rating',
                groupValue: _sortBy,
                onChanged: (value) {
                  Navigator.pop(context);
                  setState(() {
                    _sortBy = value!;
                    _applyFilters();
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Name (A-Z)'),
                value: 'name',
                groupValue: _sortBy,
                onChanged: (value) {
                  Navigator.pop(context);
                  setState(() {
                    _sortBy = value!;
                    _applyFilters();
                  });
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }
    );
  }
}
