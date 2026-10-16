import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../controllers/request_provider.dart';
import '../../../models/consultation_request.dart';
import '../../../services/lawyer_rating_service.dart';
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
  bool _filterTopRatedOnly = false;
  bool _filterSeniorOnly = false;

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

    if (_filterTopRatedOnly) {
      filtered = filtered.where((lawyer) {
        final rating = double.tryParse(lawyer['rating']?.toString() ?? '0') ?? 0.0;
        return rating >= 4.0;
      }).toList();
    }

    if (_filterSeniorOnly) {
      filtered = filtered.where((lawyer) {
        final exp = int.tryParse(lawyer['experience']?.toString() ?? '0') ?? 0;
        return exp >= 5;
      }).toList();
    }

    if (_sortBy == 'rating') {
      filtered.sort((a, b) {
        final ratingA = (a['rating'] ?? 0).toDouble();
        final ratingB = (b['rating'] ?? 0).toDouble();
        if (ratingB != ratingA) {
          return ratingB.compareTo(ratingA); // Highest rating first
        }
        // Secondary sort by experience for newly registered lawyers
        final expA = int.tryParse(a['experience']?.toString() ?? '0') ?? 0;
        final expB = int.tryParse(b['experience']?.toString() ?? '0') ?? 0;
        return expB.compareTo(expA);
      });
    } else if (_sortBy == 'experience') {
      filtered.sort((a, b) {
        final expA = int.tryParse(a['experience']?.toString() ?? '0') ?? 0;
        final expB = int.tryParse(b['experience']?.toString() ?? '0') ?? 0;
        return expB.compareTo(expA); // Highest experience first
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
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: const Color(0xFF0D256C)),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0D256C),
          elevation: 0.5,
          actions: [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.filter_list, color: Color(0xFF0D256C)),
                  tooltip: 'Filter',
                  onPressed: _showFilterDialog,
                ),
                if (_filterTopRatedOnly || _filterSeniorOnly || _sortBy != 'rating')
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          bottom: TabBar(
            labelColor: const Color(0xFF0D256C),
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: const Color(0xFF0D256C),
            indicatorWeight: 3,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 14),
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
    final rawSpec = lawyer['specialization']?.toString();
    final spec = (rawSpec != null && rawSpec.isNotEmpty) ? rawSpec : 'Advocate / Legal Practitioner';
    
    final hasAppReviews = LawyerRatingService.hasAppReviews(lawyer);
    final rating = double.tryParse(lawyer['rating']?.toString() ?? '0') ?? 0.0;
    final ratingCount = int.tryParse(lawyer['rating_count']?.toString() ?? '0') ?? 0;
    final expText = LawyerRatingService.getExperienceString(lawyer);
    
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
                      // If lawyer has received client ratings through the app, show Star Rating
                      // Otherwise, show their verified professional experience from profile
                      if (hasAppReviews)
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
                                "${rating.toStringAsFixed(1)} ($ratingCount ${ratingCount == 1 ? 'review' : 'reviews'})",
                                style: GoogleFonts.inter(
                                  color: Colors.amber[900],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A365D).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF1A365D).withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.workspace_premium_outlined, size: 14, color: Color(0xFF1A365D)),
                              const SizedBox(width: 4),
                              Text(
                                expText,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF1A365D),
                                  fontWeight: FontWeight.w600,
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
                      
                      // Refresh lawyers to reflect any rating submitted on public profile
                      if (mounted) {
                        _fetchLawyers();
                      }

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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: Color(0xFF0D256C), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Sort & Filter',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF0D256C)),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _sortBy = 'rating';
                            _filterTopRatedOnly = false;
                            _filterSeniorOnly = false;
                          });
                          setState(() => _applyFilters());
                        },
                        child: Text(
                          'Reset',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'SORT BY',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[600], letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    title: Text(
                      'Rating (Highest First)',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Sort by client reviews & star ratings',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                    ),
                    secondary: const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                    value: _sortBy == 'rating',
                    activeColor: const Color(0xFF0D256C),
                    checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (bool? checked) {
                      setModalState(() {
                        _sortBy = (checked == true) ? 'rating' : '';
                      });
                      setState(() => _applyFilters());
                    },
                  ),
                  CheckboxListTile(
                    title: Text(
                      'Experience (Most Experienced)',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Sort by years of practice at the Bar',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                    ),
                    secondary: const Icon(Icons.timeline_rounded, color: Color(0xFF0D256C), size: 24),
                    value: _sortBy == 'experience',
                    activeColor: const Color(0xFF0D256C),
                    checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (bool? checked) {
                      setModalState(() {
                        _sortBy = (checked == true) ? 'experience' : '';
                      });
                      setState(() => _applyFilters());
                    },
                  ),
                  CheckboxListTile(
                    title: Text(
                      'Name (A-Z)',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Alphabetical order by advocate name',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                    ),
                    secondary: const Icon(Icons.sort_by_alpha_rounded, color: Color(0xFF0D256C), size: 24),
                    value: _sortBy == 'name',
                    activeColor: const Color(0xFF0D256C),
                    checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (bool? checked) {
                      setModalState(() {
                        _sortBy = (checked == true) ? 'name' : '';
                      });
                      setState(() => _applyFilters());
                    },
                  ),
                  const Divider(height: 24),
                  Text(
                    'FILTER OPTIONS',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[600], letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    title: Text(
                      'Top Rated Advocates Only (4.0+ Stars)',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Filter advocates with 4.0 or higher client ratings',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                    ),
                    secondary: const Icon(Icons.verified_rounded, color: Colors.blue, size: 24),
                    value: _filterTopRatedOnly,
                    activeColor: const Color(0xFF0D256C),
                    checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (bool? checked) {
                      setModalState(() {
                        _filterTopRatedOnly = checked ?? false;
                      });
                      setState(() => _applyFilters());
                    },
                  ),
                  CheckboxListTile(
                    title: Text(
                      'Senior Advocates (5+ Years Experience)',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Filter advocates with 5 or more years of practice',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                    ),
                    secondary: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFD97706), size: 24),
                    value: _filterSeniorOnly,
                    activeColor: const Color(0xFF0D256C),
                    checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (bool? checked) {
                      setModalState(() {
                        _filterSeniorOnly = checked ?? false;
                      });
                      setState(() => _applyFilters());
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D256C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text('Done', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
