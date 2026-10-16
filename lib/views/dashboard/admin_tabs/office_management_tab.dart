import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class OfficeManagementTab extends StatefulWidget {
  const OfficeManagementTab({Key? key}) : super(key: key);

  @override
  _OfficeManagementTabState createState() => _OfficeManagementTabState();
}

class _OfficeManagementTabState extends State<OfficeManagementTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _offices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOffices();
  }

  Future<void> _fetchOffices() async {
    try {
      final data = await _supabase.from('lawyer_offices').select().order('created_at', ascending: false);
      setState(() {
        _offices = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching offices: $e');
      setState(() => _isLoading = false);
    }
  }

  String _searchQuery = '';

  void _showAddOfficeDialog() {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final imageCtrl = TextEditingController(text: 'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&q=80');
    final contactCtrl = TextEditingController();
    
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Register Legal Office', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Office / Firm Name',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationCtrl,
                      decoration: InputDecoration(
                        labelText: 'City / Jurisdiction',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressCtrl,
                      decoration: InputDecoration(
                        labelText: 'Full Physical Address',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contactCtrl,
                      decoration: InputDecoration(
                        labelText: 'Official Contact Number',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: imageCtrl,
                      decoration: InputDecoration(
                        labelText: 'Photo URL',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey[700], fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D256C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  onPressed: isSubmitting ? null : () async {
                    if (nameCtrl.text.isEmpty || locationCtrl.text.isEmpty) return;
                    
                    setDialogState(() => isSubmitting = true);
                    
                    try {
                      await _supabase.from('lawyer_offices').insert({
                        'id': Uuid().v4(),
                        'name': nameCtrl.text.trim(),
                        'location': locationCtrl.text.trim(),
                        'address': addressCtrl.text.trim(),
                        'contact_number': contactCtrl.text.trim(),
                        'image_url': imageCtrl.text.trim(),
                      });
                      
                      Navigator.pop(ctx);
                      _fetchOffices();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Office registered successfully!')));
                    } catch (e) {
                      debugPrint('Error: $e');
                      setDialogState(() => isSubmitting = false);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add office')));
                    }
                  },
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Save Office', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _deleteOffice(String id, String officeName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Office?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$officeName" from the public directory?', style: GoogleFonts.inter(color: Colors.grey[700])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey[700], fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      )
    );

    if (confirm == true) {
      try {
        await _supabase.from('lawyer_offices').delete().eq('id', id);
        _fetchOffices();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Office deleted successfully')));
      } catch (e) {
        debugPrint('Error deleting office: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _offices.where((o) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (o['name'] ?? '').toString().toLowerCase();
      final loc = (o['location'] ?? '').toString().toLowerCase();
      final addr = (o['address'] ?? '').toString().toLowerCase();
      return name.contains(q) || loc.contains(q) || addr.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOfficeDialog,
        backgroundColor: const Color(0xFF0D256C),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_business_rounded),
        label: Text('New Office', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                  hintText: 'Search offices by name, city, location...',
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

          // Office List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business_outlined, size: 56, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No offices found in directory.', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 15)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchOffices,
                    color: const Color(0xFF0D256C),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final office = filtered[index];
                        final name = office['name'] ?? 'Law Office';
                        final location = office['location'] ?? 'Location';
                        final address = office['address'] ?? '';
                        final contact = office['contact_number'] ?? 'N/A';
                        final imageUrl = office['image_url'];

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
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.blue.shade50,
                                    child: (imageUrl != null && imageUrl.toString().isNotEmpty)
                                        ? Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.business, color: Color(0xFF0D256C), size: 30),
                                          )
                                        : const Icon(Icons.business, color: Color(0xFF0D256C), size: 30),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0D256C)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              location,
                                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (contact != 'N/A') ...[
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(Icons.phone_outlined, size: 14, color: Colors.grey[500]),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                contact,
                                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (address.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          address,
                                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded, color: Colors.red[400], size: 22),
                                  tooltip: 'Delete Office',
                                  onPressed: () => _deleteOffice(office['id'], name),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
