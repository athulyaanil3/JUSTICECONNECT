import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../controllers/advocate_clerk_provider.dart';
import '../../../models/legal_case.dart';

class AdvocateClerkHearingsTab extends StatefulWidget {
  const AdvocateClerkHearingsTab({Key? key}) : super(key: key);

  @override
  _AdvocateClerkHearingsTabState createState() => _AdvocateClerkHearingsTabState();
}

class _AdvocateClerkHearingsTabState extends State<AdvocateClerkHearingsTab> {
  String? _selectedCaseId;
  String _remarks = '';
  bool _notifyLawyers = true;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(text: 'Record Hearing Info'),
              Tab(text: 'Daily Cause List'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildScheduleHearings(context),
                _buildCauseList(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleHearings(BuildContext context) {
    final provider = Provider.of<AdvocateClerkProvider>(context);
    final activeCases = provider.cases.where((c) => 
      c.status == 'Ready for Court Process' || 
      c.status == 'Proceeding' || 
      c.status == 'Hearing Scheduled' || 
      c.status == 'Hearing Completed'
    ).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Record New Hearing Info', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Select Case'),
                  value: _selectedCaseId,
                  items: activeCases.map((c) => DropdownMenuItem(
                    value: c.id, 
                    child: Text('${c.caseNumber} (${c.title})')
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCaseId = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Hearing Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text('${_selectedDate.toLocal()}'.split(' ')[0]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Time',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.access_time),
                          ),
                          child: Text(_selectedTime.format(context)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(labelText: 'Remarks (Courtroom, Judge, etc.)', border: OutlineInputBorder()),
                  onChanged: (val) {
                    setState(() {
                      _remarks = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _notifyLawyers, 
                      onChanged: (v) {
                        setState(() => _notifyLawyers = v ?? true);
                      }
                    ),
                    const Text('Automatically Notify Parties'),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_selectedCaseId != null) {
                        final dateTime = DateTime(
                          _selectedDate.year,
                          _selectedDate.month,
                          _selectedDate.day,
                          _selectedTime.hour,
                          _selectedTime.minute,
                        );

                        provider.recordHearingInformation(
                          _selectedCaseId!, 
                          dateTime, 
                          _selectedTime.format(context), 
                          _remarks, 
                          _notifyLawyers
                        );
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hearing Info Recorded')));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a case', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Record Hearing'),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCauseList(BuildContext context) {
    final provider = Provider.of<AdvocateClerkProvider>(context);
    final hearings = provider.hearings;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cause List for Today', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              OutlinedButton.icon(
                onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature available in full version'))); },
                icon: const Icon(Icons.print),
                label: const Text('Generate'),
              )
            ],
          ),
        ),
        Expanded(
          child: hearings.isEmpty 
            ? Center(child: Text('No hearings found.', style: GoogleFonts.inter(color: Colors.grey)))
            : ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onReorder: (oldIndex, newIndex) {},
                itemCount: hearings.length,
                itemBuilder: (context, index) {
                  final h = hearings[index];
                  // Find case safely
                  LegalCase? c;
                  try {
                    c = provider.cases.firstWhere((caseItem) => caseItem.id == h.caseId);
                  } catch (_) {}
                  
                  return Card(
                    key: ValueKey(h.id),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text('${c?.caseNumber ?? 'Unknown'} - ${c?.title ?? 'Unknown'}', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      subtitle: Text('${h.remarks} • ${h.hearingDate.toString().substring(11, 16)}\nStatus: ${h.status}'),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (val) {
                          provider.updateHearingStatus(h.id, h.caseId, val, 'Status updated by Advocate Clerk');
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'Completed', child: Text('Mark Completed')),
                          const PopupMenuItem(value: 'Postponed', child: Text('Postpone Hearing')),
                          const PopupMenuItem(value: 'Cancelled', child: Text('Cancel Hearing')),
                        ],
                        icon: const Icon(Icons.more_vert),
                      ),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }
}
