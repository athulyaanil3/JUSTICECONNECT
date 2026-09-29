import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoleManagementTab extends StatefulWidget {
  const RoleManagementTab({Key? key}) : super(key: key);

  @override
  _RoleManagementTabState createState() => _RoleManagementTabState();
}

class _RoleManagementTabState extends State<RoleManagementTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  
  // Available default roles. In a real system, these might come from a `roles` table.
  final List<String> _availableRoles = ['Citizen', 'Lawyer', 'Advocate Clerk', 'Administrator'];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error fetching users: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateUserRole(String id, String newRole) async {
    try {
      await _supabase
          .from('profiles')
          .update({'role': newRole})
          .eq('id', id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User role updated to $newRole'),
          backgroundColor: Colors.green,
        ),
      );
      
      _fetchUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showCreateRoleDialog() {
    final roleController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Create Custom Role', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: roleController,
                decoration: const InputDecoration(labelText: 'Role Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Text(
                'Note: Custom permissions require RBAC backend implementation.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (roleController.text.isNotEmpty) {
                  setState(() {
                    _availableRoles.add(roleController.text);
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Role "${roleController.text}" created.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _showCreateRoleDialog,
            icon: const Icon(Icons.security),
            label: const Text('Create Custom Role'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetchUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final currentRole = user['role'] ?? 'Citizen';
                      
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.purple.withOpacity(0.1),
                            child: const Icon(Icons.manage_accounts, color: Colors.purple),
                          ),
                          title: Text(
                            user['username'] ?? 'Unknown User',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          subtitle: Text(
                            'Current Role: $currentRole\nEmail: ${user['email'] ?? 'N/A'}',
                            style: GoogleFonts.inter(color: Colors.grey[600]),
                          ),
                          isThreeLine: true,
                          trailing: Chip(
                            label: Text(
                              currentRole,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: Colors.purple.withOpacity(0.1),
                            side: BorderSide.none,
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
