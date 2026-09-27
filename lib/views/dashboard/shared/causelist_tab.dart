import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/legal_case.dart';
import '../../widgets/causelist_card.dart';

class CauselistTab extends StatefulWidget {
  final String role; // 'Lawyer', 'Advocate Clerk', 'Citizen'

  const CauselistTab({Key? key, required this.role}) : super(key: key);

  @override
  _CauselistTabState createState() => _CauselistTabState();
}

class _CauselistTabState extends State<CauselistTab> {
  final _supabase = Supabase.instance.client;
  List<LegalCase> _cases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCauselist();
  }

  Future<void> _fetchCauselist() async {
    setState(() => _isLoading = true);
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Query depends on role
      late final List<Map<String, dynamic>> response;
      if (widget.role == 'Lawyer') {
        response = await _supabase.from('cases').select().eq('lawyer_id', userId).not('case_number', 'eq', '').order('next_hearing_date', ascending: true);
      } else if (widget.role == 'Advocate Clerk') {
        response = await _supabase.from('cases').select().eq('advocate_clerk_id', userId).not('case_number', 'eq', '').order('next_hearing_date', ascending: true);
      } else {
        response = await _supabase.from('cases').select().eq('user_id', userId).not('case_number', 'eq', '').order('next_hearing_date', ascending: true);
      }

      setState(() {
        _cases = response.map((c) => LegalCase.fromJson(c)).toList();
      });
    } catch (e) {
      debugPrint('Error fetching causelist: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showUpdateDialog(LegalCase c) {
    // Only Lawyer and Clerk can update
    if (widget.role == 'Citizen') return;

    final purposeController = TextEditingController(text: c.purpose);
    DateTime? selectedDate = c.nextHearingDate;
    String selectedStatus = c.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Update Case Status'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: purposeController,
                    decoration: const InputDecoration(labelText: 'Purpose', hintText: 'e.g. Next Hearing, Final Argument'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: Text(selectedDate == null ? 'Select Next Hearing Date' : 'Next Hearing: ${selectedDate!.toString().substring(0, 10)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setState(() => selectedDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    items: ['Ongoing', 'Completed', 'Resolved'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedStatus = val);
                    },
                    decoration: const InputDecoration(labelText: 'Case Status'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  await _updateCase(c.id, selectedDate, purposeController.text, selectedStatus);
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: const Text('Update'),
              )
            ],
          );
        }
      ),
    );
  }

  Future<void> _updateCase(String caseId, DateTime? nextHearing, String purpose, String status) async {
    try {
      await _supabase.from('cases').update({
        'next_hearing_date': nextHearing?.toIso8601String(),
        'purpose': purpose,
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', caseId);

      await _supabase.from('case_updates').insert({
        'case_id': caseId,
        'update_type': 'Case Details Updated',
        'description': 'Updated by ${widget.role}. Next Hearing: ${nextHearing?.toIso8601String().substring(0,10)}. Purpose: $purpose.',
        'created_by': _supabase.auth.currentUser!.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      _fetchCauselist();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Case updated successfully')));
      }
    } catch (e) {
      debugPrint('Error updating case: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Causelist', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D256C),
        elevation: 1,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchCauselist),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _cases.isEmpty 
          ? Center(
              child: Text(
                'No official cases found in your Causelist.', 
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 16),
              )
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _cases.length,
              itemBuilder: (context, index) {
                return CauselistCard(
                  legalCase: _cases[index],
                  onTap: () => _showUpdateDialog(_cases[index]),
                );
              },
            ),
    );
  }
}
