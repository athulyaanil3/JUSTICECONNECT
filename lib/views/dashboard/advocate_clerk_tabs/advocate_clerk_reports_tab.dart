import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdvocateClerkReportsTab extends StatelessWidget {
  const AdvocateClerkReportsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Generate Reports', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildReportButton(context, 'Daily Report', Icons.calendar_view_day),
            const SizedBox(width: 12),
            _buildReportButton(context, 'Monthly Report', Icons.calendar_month),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildReportButton(context, 'Pending Cases', Icons.pending_actions),
            const SizedBox(width: 12),
            _buildReportButton(context, 'Hearing Stats', Icons.bar_chart),
          ],
        ),
        const SizedBox(height: 32),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recent Reports', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: const Text('Daily_Report_Oct14.pdf'),
                  trailing: IconButton(icon: const Icon(Icons.download), onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature available in full version'))); }),
                ),
                ListTile(
                  leading: const Icon(Icons.table_chart, color: Colors.green),
                  title: const Text('Pending_Cases_Q3.csv'),
                  trailing: IconButton(icon: const Icon(Icons.download), onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature available in full version'))); }),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildReportButton(BuildContext context, String title, IconData icon) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature available in full version'))); },
        icon: Icon(icon, color: Colors.white),
        label: Text(title, style: const TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
