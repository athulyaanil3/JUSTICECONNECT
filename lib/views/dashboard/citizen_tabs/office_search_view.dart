import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/lawyer_office.dart';
import 'office_details_screen.dart';

class OfficeSearchView extends StatefulWidget {
  final VoidCallback? onBookingSuccess;
  const OfficeSearchView({Key? key, this.onBookingSuccess}) : super(key: key);

  @override
  _OfficeSearchViewState createState() => _OfficeSearchViewState();
}

class _OfficeSearchViewState extends State<OfficeSearchView> {
  String _searchQuery = '';
  List<LawyerOffice> _allOffices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOffices();
  }

  Future<void> _fetchOffices() async {
    try {
      final supabase = Supabase.instance.client;
      // Fetch lawyer offices and their corresponding lawyers in a single query
      final response = await supabase.from('lawyer_offices').select('*, office_lawyers(*)').order('rating', ascending: false);
      
      setState(() {
        _allOffices = List<LawyerOffice>.from(
          (response as List<dynamic>).map((x) => LawyerOffice.fromJson(x as Map<String, dynamic>)),
        );
      });
    } catch (e) {
      debugPrint('Error fetching lawyer offices: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<LawyerOffice> get _filteredOffices {
    if (_searchQuery.isEmpty) return _allOffices;
    final lowerQuery = _searchQuery.toLowerCase();
    return _allOffices.where((office) =>
        office.name.toLowerCase().contains(lowerQuery) ||
        office.location.toLowerCase().contains(lowerQuery)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search offices by name or location...',
              hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.location_on_outlined),
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
              : _filteredOffices.isEmpty
                  ? Center(
                      child: Text(
                        'No lawyer offices found in this location.',
                        style: GoogleFonts.inter(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: _filteredOffices.length,
                      itemBuilder: (context, index) {
                        return _buildOfficeCard(context, _filteredOffices[index]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildOfficeCard(BuildContext context, LawyerOffice office) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      shadowColor: Colors.black12,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OfficeDetailsScreen(office: office, onBookingSuccess: widget.onBookingSuccess),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                image: DecorationImage(
                  image: NetworkImage(office.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          office.name,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber[600]),
                          const SizedBox(width: 4),
                          Text(
                            office.rating.toString(),
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          office.location,
                          style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 16, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        '${office.lawyers.length} Lawyers Available',
                        style: GoogleFonts.inter(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
