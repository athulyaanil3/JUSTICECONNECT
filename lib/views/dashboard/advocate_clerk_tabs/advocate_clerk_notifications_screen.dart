import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdvocateClerkNotificationsScreen extends StatelessWidget {
  const AdvocateClerkNotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications & Alerts', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      backgroundColor: Colors.grey[50],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Send New Alert', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Target Audience'),
                    items: const [
                      DropdownMenuItem(value: 'All Lawyers', child: Text('All Lawyers')),
                      DropdownMenuItem(value: 'Specific Case Lawyers', child: Text('Specific Case Lawyers')),
                      DropdownMenuItem(value: 'General Public', child: Text('General Public')),
                    ],
                    onChanged: (val) {},
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Alert Type'),
                    items: const [
                      DropdownMenuItem(value: 'Hearing Change', child: Text('Hearing Change / Adjournment')),
                      DropdownMenuItem(value: 'Court Announcement', child: Text('Court Announcement')),
                      DropdownMenuItem(value: 'Document Request', child: Text('Document Request')),
                    ],
                    onChanged: (val) {},
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Message Body',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Notification Sent Successfully')),
                        );
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('Send Notification'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Recent Sent Notifications', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildNotificationItem('Hearing Adjourned', 'Case 2026-001 has been moved to 2PM.', '1 hr ago', Icons.access_time, Colors.orange),
          _buildNotificationItem('Court Announcement', 'Courtroom 3 will be closed for maintenance today.', '3 hrs ago', Icons.campaign, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(String title, String desc, String time, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        subtitle: Text(desc, style: GoogleFonts.inter()),
        trailing: Text(time, style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
      ),
    );
  }
}
