import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/legal_case.dart';
import '../../../services/email_notification_service.dart';
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
    final statusController = TextEditingController(text: c.status);
    DateTime? selectedDate = c.nextHearingDate;

    final commonStatuses = [
      'Ongoing',
      'Hearing Scheduled',
      'Adjourned',
      'Arguments Heard',
      'Order Reserved',
      'Disposed',
      'Completed',
      'Resolved',
      'Dismissed',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Update Hearing Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: purposeController,
                    decoration: const InputDecoration(
                      labelText: 'Purpose', 
                      hintText: 'e.g. Next Hearing, Final Argument',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      selectedDate == null 
                        ? 'Select Next Hearing Date' 
                        : 'Next Hearing: ${selectedDate!.toString().substring(0, 10)}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    ),
                    trailing: const Icon(Icons.calendar_today, color: Color(0xFF0D256C)),
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
                  Text(
                    'Case Status',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: statusController,
                    decoration: InputDecoration(
                      hintText: 'Type custom status or choose from list...',
                      suffixIcon: PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0D256C)),
                        tooltip: 'Select status',
                        onSelected: (val) {
                          statusController.text = val;
                          setState(() {});
                        },
                        itemBuilder: (context) => commonStatuses
                            .map((s) => PopupMenuItem(value: s, child: Text(s)))
                            .toList(),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: ['Ongoing', 'Adjourned', 'Hearing Scheduled', 'Completed', 'Resolved'].map((s) {
                      final isSelected = statusController.text.trim().toLowerCase() == s.toLowerCase();
                      return ChoiceChip(
                        label: Text(s, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87)),
                        selected: isSelected,
                        selectedColor: const Color(0xFF0D256C),
                        onSelected: (selected) {
                          if (selected) {
                            statusController.text = s;
                            setState(() {});
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D256C),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final finalStatus = statusController.text.trim().isEmpty ? 'Ongoing' : statusController.text.trim();
                  await _updateCase(c.id, selectedDate, purposeController.text, finalStatus);
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

      final updateDesc = 'Updated by ${widget.role}. Next Hearing: ${nextHearing?.toIso8601String().substring(0,10)}. Purpose: $purpose.';
      await _supabase.from('case_updates').insert({
        'case_id': caseId,
        'update_type': 'Case Details Updated',
        'description': updateDesc,
        'created_by': _supabase.auth.currentUser!.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Send email to user
      EmailNotificationService.sendCaseUpdateEmail(
        caseId: caseId,
        updateType: 'Case Details Updated',
        description: updateDesc,
        role: widget.role,
      );

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
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text(
          'Hearing Schedule',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: const Color(0xFF0D256C)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D256C),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCauselist,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _cases.isEmpty 
          ? Center(
              child: Text(
                'No hearings scheduled yet.', 
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
