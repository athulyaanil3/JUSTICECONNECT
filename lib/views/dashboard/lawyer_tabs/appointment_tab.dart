import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AppointmentTab extends StatefulWidget {
  const AppointmentTab({Key? key}) : super(key: key);

  @override
  _AppointmentTabState createState() => _AppointmentTabState();
}

class _AppointmentTabState extends State<AppointmentTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'unknown';
    final data = prefs.getString('lawyer_appointments_$userId');
    if (data != null) {
      final List<dynamic> decoded = json.decode(data);
      setState(() {
        _appointments = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoading = false;
      });
    } else {
      // Default dummy data if nothing exists
      setState(() {
        _appointments = [
          {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'title': 'Rahul Menon',
            'subtitle': 'Online Consultation',
            'time': '11:00 AM',
            'date': DateTime.now().toIso8601String(),
          },
          {
            'id': (DateTime.now().millisecondsSinceEpoch + 1).toString(),
            'title': 'Sneha John',
            'subtitle': 'Office Visit',
            'time': '02:30 PM',
            'date': DateTime.now().toIso8601String(),
          }
        ];
        _isLoading = false;
      });
      _saveAppointments();
    }
  }

  Future<void> _saveAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'unknown';
    await prefs.setString('lawyer_appointments_$userId', json.encode(_appointments));
  }

  void _addAppointment(String title, String subtitle, String time, DateTime date) {
    setState(() {
      _appointments.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': title,
        'subtitle': subtitle,
        'time': time,
        'date': date.toIso8601String(),
      });
      // Sort by date then time (simple approximation)
      _appointments.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
    });
    _saveAppointments();
  }

  void _deleteAppointment(String id) {
    setState(() {
      _appointments.removeWhere((app) => app['id'] == id);
    });
    _saveAppointments();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Appointment deleted'), backgroundColor: Colors.redAccent),
    );
  }

  void _showAddAppointmentDialog() {
    final titleController = TextEditingController();
    final subtitleController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('New Appointment', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Client Name / Title',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subtitleController,
                    decoration: InputDecoration(
                      labelText: 'Purpose / Details',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
                    ),
                    title: Text(DateFormat('MMM dd, yyyy').format(selectedDate), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (d != null) {
                        setDialogState(() => selectedDate = d);
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.access_time, color: Colors.purple),
                    ),
                    title: Text(selectedTime.format(context), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (t != null) {
                        setDialogState(() => selectedTime = t);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (titleController.text.isNotEmpty) {
                    _addAppointment(
                      titleController.text,
                      subtitleController.text.isEmpty ? 'Scheduled Appointment' : subtitleController.text,
                      selectedTime.format(context),
                      selectedDate,
                    );
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Add'),
              )
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required for AutomaticKeepAliveClientMixin
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Group appointments by Date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var app in _appointments) {
      final dateStr = DateFormat('MMM dd, yyyy').format(DateTime.parse(app['date']));
      if (!grouped.containsKey(dateStr)) {
        grouped[dateStr] = [];
      }
      grouped[dateStr]!.add(app);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text(
          'My Schedule',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF0D256C),
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAppointmentDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Appointment'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: grouped.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No appointments scheduled', style: GoogleFonts.inter(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100, left: 16, right: 16, top: 10),
              itemCount: grouped.keys.length,
              itemBuilder: (context, index) {
                final dateStr = grouped.keys.elementAt(index);
                final apps = grouped[dateStr]!;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              dateStr,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider(indent: 12)),
                        ],
                      ),
                    ),
                    ...apps.map((app) => _buildScheduleCard(app)).toList(),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Dismissible(
          key: Key(app['id']),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.redAccent,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) {
            _deleteAppointment(app['id']);
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Time Bubble
                Container(
                  width: 80,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[400]!, Colors.blue[600]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        app['time'].split(' ')[0],
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                      ),
                      Text(
                        app['time'].split(' ').length > 1 ? app['time'].split(' ')[1] : '',
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app['title'],
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.description_outlined, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              app['subtitle'],
                              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Delete Button
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Appointment?'),
                        content: const Text('Are you sure you want to remove this appointment?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _deleteAppointment(app['id']);
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
