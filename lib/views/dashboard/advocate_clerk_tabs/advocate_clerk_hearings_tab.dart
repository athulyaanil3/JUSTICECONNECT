import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../controllers/advocate_clerk_provider.dart';
import '../../../models/legal_case.dart';
import '../../../models/hearing.dart';
import 'advocate_clerk_messages_screen.dart';
import 'advocate_clerk_notifications_screen.dart';

class AdvocateClerkHearingsTab extends StatefulWidget {
  const AdvocateClerkHearingsTab({Key? key}) : super(key: key);

  @override
  _AdvocateClerkHearingsTabState createState() => _AdvocateClerkHearingsTabState();
}

class _AdvocateClerkHearingsTabState extends State<AdvocateClerkHearingsTab> {
  // Tab 1: Form state
  String? _selectedCaseId;
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _courtroomController = TextEditingController();
  String _selectedPurpose = 'First Hearing / Admission';
  bool _notifyLawyers = true;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 30);
  bool _isRecording = false;

  // Tab 2: Filter and search state
  String _filter = 'all'; // 'all', 'today', 'upcoming', 'completed'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _purposeOptions = [
    'First Hearing / Admission',
    'Arguments / Hearing',
    'Evidence & Witness Examination',
    'Cross Examination',
    'Bail Hearing',
    'Interlocutory Application (IA)',
    'Notice & Service Return',
    'Framing of Issues',
    'Final Arguments & Order',
    'Other Special Proceedings',
  ];

  @override
  void dispose() {
    _remarksController.dispose();
    _courtroomController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D256C),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D256C),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
    }
  }

  void _onCaseSelected(String? caseId, List<LegalCase> cases) {
    setState(() {
      _selectedCaseId = caseId;
      if (caseId != null) {
        try {
          final matchedCase = cases.firstWhere((c) => c.id == caseId);
          if (matchedCase.courtName != null && matchedCase.courtName!.isNotEmpty) {
            _courtroomController.text = matchedCase.courtName!;
          }
          if (matchedCase.purpose != null && matchedCase.purpose!.isNotEmpty) {
            if (_purposeOptions.contains(matchedCase.purpose)) {
              _selectedPurpose = matchedCase.purpose!;
            } else {
              _remarksController.text = matchedCase.purpose!;
            }
          }
          if (matchedCase.nextHearingDate != null) {
            _selectedDate = matchedCase.nextHearingDate!.toLocal();
            _selectedTime = TimeOfDay.fromDateTime(matchedCase.nextHearingDate!.toLocal());
          }
        } catch (_) {}
      }
    });
  }

  Future<void> _submitHearingInfo() async {
    if (_selectedCaseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a case to record hearing details.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isRecording = true);

    try {
      final provider = Provider.of<AdvocateClerkProvider>(context, listen: false);
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final formattedTime = _selectedTime.format(context);
      final remarks = _remarksController.text.trim();
      final courtroom = _courtroomController.text.trim();

      await provider.recordHearingInformation(
        _selectedCaseId!,
        dateTime,
        formattedTime,
        remarks,
        _notifyLawyers,
        hearingType: _selectedPurpose,
        courtroom: courtroom,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hearing scheduled for ${DateFormat('dd MMM yyyy').format(dateTime)} at $formattedTime!',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );

        // Reset inputs
        setState(() {
          _remarksController.clear();
          _courtroomController.clear();
          _selectedCaseId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record hearing: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRecording = false);
      }
    }
  }

  void _showRescheduleDialog(Hearing h, LegalCase? c) {
    DateTime newDate = h.hearingDate;
    TimeOfDay newTime = TimeOfDay.fromDateTime(h.hearingDate);
    final reasonController = TextEditingController();
    final courtroomController = TextEditingController(text: h.courtroom);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D256C).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.event_repeat, color: Color(0xFF0D256C)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reschedule / Adjourn Hearing',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0D256C),
                              ),
                            ),
                            Text(
                              '${c?.caseNumber ?? 'Case'} - ${c?.title ?? ''}',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: newDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 1)),
                              lastDate: DateTime(2101),
                            );
                            if (picked != null) {
                              setModalState(() => newDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16, color: Color(0xFF0D256C)),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(newDate),
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: newTime,
                            );
                            if (picked != null) {
                              setModalState(() => newTime = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: Color(0xFF0D256C)),
                                const SizedBox(width: 8),
                                Text(
                                  newTime.format(context),
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: courtroomController,
                    decoration: InputDecoration(
                      labelText: 'Courtroom / Bench',
                      hintText: 'e.g. Court Hall 2',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      labelText: 'Reason for Adjournment / Notes',
                      hintText: 'e.g. Adjourned at request of counsel',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final provider = Provider.of<AdvocateClerkProvider>(context, listen: false);
                        final finalDateTime = DateTime(
                          newDate.year,
                          newDate.month,
                          newDate.day,
                          newTime.hour,
                          newTime.minute,
                        );
                        final reason = reasonController.text.trim();
                        final courtroom = courtroomController.text.trim();
                        final messenger = ScaffoldMessenger.of(context);

                        Navigator.pop(ctx);
                        try {
                          await provider.updateHearingStatus(
                            h.id,
                            h.caseId,
                            'Adjourned',
                            reason.isNotEmpty ? reason : 'Hearing Adjourned to next date',
                            newDate: finalDateTime,
                            newTime: newTime.format(context),
                            newCourtroom: courtroom,
                          );
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Hearing successfully rescheduled / adjourned.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D256C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Confirm Reschedule', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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

  void _shareCauseList(List<Hearing> hearings, List<LegalCase> cases) {
    if (hearings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hearings to export in the cause list.')),
      );
      return;
    }

    final dateStr = DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now());
    final buffer = StringBuffer();
    buffer.writeln('====================================');
    buffer.writeln('   JUSTICECONNECT DAILY CAUSE LIST  ');
    buffer.writeln('   Date: $dateStr');
    buffer.writeln('====================================\n');

    int idx = 1;
    for (final h in hearings) {
      LegalCase? c;
      try {
        c = cases.firstWhere((caseItem) => caseItem.id == h.caseId);
      } catch (_) {}

      final caseNum = c?.caseNumber.isNotEmpty == true ? c!.caseNumber : 'Unassigned';
      final title = c?.title ?? 'Case Title';
      final timeStr = DateFormat('hh:mm a').format(h.hearingDate.toLocal());
      final court = h.courtroom.isNotEmpty ? h.courtroom : (c?.courtName ?? 'Assigned Court');

      buffer.writeln('$idx. Item #$caseNum');
      buffer.writeln('   Case: $title');
      buffer.writeln('   Time: $timeStr | Court: $court');
      buffer.writeln('   Purpose: ${h.hearingType}');
      buffer.writeln('   Status: ${h.status}');
      if (h.remarks.isNotEmpty) {
        buffer.writeln('   Notes: ${h.remarks}');
      }
      buffer.writeln('------------------------------------');
      idx++;
    }

    buffer.writeln('\nOfficial extract generated by Advocate Clerk Console.');

    Share.share(
      buffer.toString(),
      subject: 'Daily Cause List - $dateStr',
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          title: Text(
            'Hearings Management',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: const Color(0xFF0D256C)),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0D256C),
          elevation: 0.5,
          actions: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF0D256C)),
              tooltip: 'Lawyer Messages',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdvocateClerkMessagesScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Color(0xFF0D256C)),
              tooltip: 'Notifications',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdvocateClerkNotificationsScreen()),
                );
              },
            ),
          ],
          bottom: TabBar(
            labelColor: const Color(0xFF0D256C),
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: const Color(0xFFD4AF37),
            indicatorWeight: 3,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 14),
            tabs: const [
              Tab(
                icon: Icon(Icons.edit_calendar, size: 20),
                text: 'Record Hearing',
              ),
              Tab(
                icon: Icon(Icons.format_list_bulleted, size: 20),
                text: 'Hearing Schedule',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRecordHearingForm(context),
            _buildHearingScheduleList(context),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: Record / Update Hearing Form ---
  Widget _buildRecordHearingForm(BuildContext context) {
    final provider = Provider.of<AdvocateClerkProvider>(context);
    // Display all active / open cases (excluding closed and dismissed)
    final activeCases = provider.cases.where((c) =>
      c.status != 'Closed' && c.status != 'Dismissed'
    ).toList();

    return RefreshIndicator(
      onRefresh: () => provider.fetchAllData(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D256C), Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D256C).withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.gavel, color: Color(0xFFD4AF37), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record Hearing Information',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Update court dates, courtroom, and cause list for clients & counsel.',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 1,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Court Case *',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: const Color(0xFF0D256C),
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (activeCases.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No active cases currently found. Cases filed or admitted will automatically appear here.',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.amber.shade900),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        hintText: 'Choose a case from court registry',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        prefixIcon: const Icon(Icons.folder_open, color: Color(0xFF0D256C)),
                      ),
                      value: activeCases.any((c) => c.id == _selectedCaseId) ? _selectedCaseId : null,
                      isExpanded: true,
                      items: activeCases.map((c) {
                        final ref = c.caseNumber.isNotEmpty ? c.caseNumber : 'No Ref';
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            '$ref: ${c.title} [${c.status}]',
                            style: GoogleFonts.inter(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => _onCaseSelected(val, activeCases),
                    ),

                  const SizedBox(height: 18),

                  // Hearing Purpose / Type Dropdown
                  Text(
                    'Hearing Purpose / Stage *',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: const Color(0xFF0D256C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF0D256C)),
                    ),
                    value: _selectedPurpose,
                    isExpanded: true,
                    items: _purposeOptions.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text(p, style: GoogleFonts.inter(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPurpose = val);
                    },
                  ),

                  const SizedBox(height: 18),

                  // Date and Time Pickers
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hearing Date *',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: const Color(0xFF0D256C),
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _selectDate(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_month, color: Color(0xFF0D256C), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        DateFormat('dd MMM yyyy').format(_selectedDate),
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Court Time *',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: const Color(0xFF0D256C),
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _selectTime(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time, color: Color(0xFF0D256C), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _selectedTime.format(context),
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Courtroom / Bench
                  Text(
                    'Courtroom / Bench (Optional)',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: const Color(0xFF0D256C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _courtroomController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Court Hall 3, District Court, Bench A',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.account_balance_outlined, color: Color(0xFF0D256C)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Remarks
                  Text(
                    'Remarks & Notes (Optional)',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: const Color(0xFF0D256C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _remarksController,
                    decoration: InputDecoration(
                      hintText: 'Judge name, item number, document filing instructions...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.description_outlined, color: Color(0xFF0D256C)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    maxLines: 2,
                  ),

                  const SizedBox(height: 14),

                  // Notify checkbox
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: CheckboxListTile(
                      value: _notifyLawyers,
                      onChanged: (v) => setState(() => _notifyLawyers = v ?? true),
                      title: Text(
                        'Notify Parties Automatically',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Sends instant in-app alerts and case timeline updates to lawyer & citizen.',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      activeColor: const Color(0xFF0D256C),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                  ),

                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isRecording || activeCases.isEmpty ? null : _submitHearingInfo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D256C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      child: _isRecording
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Record Hearing Information',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: Hearing Schedule & Daily Cause List ---
  Widget _buildHearingScheduleList(BuildContext context) {
    final provider = Provider.of<AdvocateClerkProvider>(context);
    final allHearings = provider.hearings;
    final allCases = provider.cases;

    final now = DateTime.now();

    // Apply filter
    List<Hearing> filtered = allHearings.where((h) {
      final hDate = h.hearingDate.toLocal();
      if (_filter == 'today') {
        return hDate.year == now.year && hDate.month == now.month && hDate.day == now.day;
      } else if (_filter == 'upcoming') {
        final startOfToday = DateTime(now.year, now.month, now.day);
        return hDate.isAfter(startOfToday.add(const Duration(days: 1))) &&
            h.status != 'Completed' &&
            h.status != 'Cancelled';
      } else if (_filter == 'completed') {
        return h.status == 'Completed' || h.status == 'Adjourned';
      }
      return true; // 'all'
    }).toList();

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((h) {
        LegalCase? c;
        try {
          c = allCases.firstWhere((caseItem) => caseItem.id == h.caseId);
        } catch (_) {}
        final caseNum = (c?.caseNumber ?? '').toLowerCase();
        final title = (c?.title ?? '').toLowerCase();
        final court = h.courtroom.toLowerCase();
        final remarks = h.remarks.toLowerCase();
        return caseNum.contains(q) || title.contains(q) || court.contains(q) || remarks.contains(q);
      }).toList();
    }

    return Column(
      children: [
        // Top filter bar & search bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Search input
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by case number, title, or courtroom...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF0D256C)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
              const SizedBox(height: 10),

              // Filter chips + Export action
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All', 'all'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Today', 'today'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Upcoming', 'upcoming'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Completed / Adjourned', 'completed'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Share / Export Cause List',
                    icon: const Icon(Icons.share, color: Color(0xFF0D256C)),
                    onPressed: () => _shareCauseList(filtered, allCases),
                  ),
                ],
              ),
            ],
          ),
        ),

        // List View
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => provider.fetchAllData(),
            child: filtered.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No hearings found for this filter.',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Use the "Record Hearing" tab to schedule court hearings.',
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final h = filtered[index];
                      LegalCase? c;
                      try {
                        c = allCases.firstWhere((caseItem) => caseItem.id == h.caseId);
                      } catch (_) {}

                      return _buildHearingCard(context, h, c, provider);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _filter = value);
      },
      selectedColor: const Color(0xFF0D256C),
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : Colors.grey.shade700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(
        color: isSelected ? const Color(0xFF0D256C) : Colors.transparent,
      ),
    );
  }

  Widget _buildHearingCard(
    BuildContext context,
    Hearing h,
    LegalCase? c,
    AdvocateClerkProvider provider,
  ) {
    final localDate = h.hearingDate.toLocal();
    final now = DateTime.now();
    final isToday = localDate.year == now.year && localDate.month == now.month && localDate.day == now.day;
    final isTomorrow = localDate.year == now.year && localDate.month == now.month && localDate.day == now.day + 1;

    final caseRef = c?.caseNumber.isNotEmpty == true ? c!.caseNumber : 'Ref: ${h.caseId.substring(0, 8)}';
    final caseTitle = c?.title ?? 'Court Matter';
    final court = h.courtroom.isNotEmpty ? h.courtroom : (c?.courtName ?? 'Assigned Court');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isToday ? const Color(0xFFD4AF37) : Colors.grey.shade200,
          width: isToday ? 1.5 : 1,
        ),
      ),
      elevation: isToday ? 2 : 1,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Case Number + Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D256C).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          caseRef,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0D256C),
                          ),
                        ),
                      ),
                      if (isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'TODAY',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else if (isTomorrow)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade700,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'TOMORROW',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusBadge(h.status),
              ],
            ),
            const SizedBox(height: 10),

            // Case Title
            Text(
              caseTitle,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),

            // Meta Info Grid (Date, Time, Court)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, size: 16, color: Color(0xFF0D256C)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            DateFormat('dd MMM yyyy').format(localDate),
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 16, color: Color(0xFF0D256C)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            DateFormat('hh:mm a').format(localDate),
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Court & Purpose row
            Row(
              children: [
                const Icon(Icons.account_balance, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    court,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
                if (h.hearingType.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      h.hearingType,
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                    ),
                  ),
                ],
              ],
            ),

            if (h.remarks.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      h.remarks,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ],

            const Divider(height: 20),

            // Action Buttons
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showRescheduleDialog(h, c),
                  icon: const Icon(Icons.edit_calendar, size: 15),
                  label: const Text('Reschedule / Adjourn'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D256C),
                    side: const BorderSide(color: Color(0xFF0D256C)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'More Hearing Actions',
                  onSelected: (val) async {
                    if (val == 'Completed') {
                      await provider.updateHearingStatus(
                        h.id,
                        h.caseId,
                        'Completed',
                        'Hearing concluded by advocate clerk.',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Hearing marked as Completed.')),
                        );
                      }
                    } else if (val == 'Cancelled') {
                      await provider.updateHearingStatus(
                        h.id,
                        h.caseId,
                        'Cancelled',
                        'Hearing cancelled.',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Hearing marked as Cancelled.')),
                        );
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'Completed',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Text('Mark Completed'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'Cancelled',
                      child: Row(
                        children: [
                          Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Text('Cancel Hearing'),
                        ],
                      ),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;

    switch (status.toLowerCase()) {
      case 'completed':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      case 'adjourned':
      case 'postponed':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      case 'cancelled':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        break;
      default:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
