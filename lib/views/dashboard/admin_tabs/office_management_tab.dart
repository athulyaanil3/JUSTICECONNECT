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
              title: Text('Add New Office', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Office Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(labelText: 'City / Location'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(labelText: 'Full Address'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contactCtrl,
                      decoration: const InputDecoration(labelText: 'Contact Number'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: imageCtrl,
                      decoration: const InputDecoration(labelText: 'Image URL'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
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
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Office added successfully!')));
                    } catch (e) {
                      debugPrint('Error: $e');
                      setDialogState(() => isSubmitting = false);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add office')));
                    }
                  },
                  child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add Office'),
                )
              ],
            );
          }
        );
      }
    );
  }

  void _deleteOffice(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Office?'),
        content: const Text('Are you sure you want to delete this office?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete')
          ),
        ],
      )
    );

    if (confirm == true) {
      try {
        await _supabase.from('lawyer_offices').delete().eq('id', id);
        _fetchOffices();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Office deleted')));
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

    return Scaffold(
      body: _offices.isEmpty
          ? Center(child: Text('No offices found.', style: GoogleFonts.inter(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _offices.length,
              itemBuilder: (context, index) {
                final office = _offices[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(office['image_url'] ?? ''),
                      backgroundColor: Colors.blue[100],
                      child: office['image_url'] == null ? const Icon(Icons.business) : null,
                    ),
                    title: Text(office['name'], style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    subtitle: Text('${office['location']}\n${office['contact_number']}', maxLines: 2),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteOffice(office['id']),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOfficeDialog,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add New Office',
      ),
    );
  }
}
