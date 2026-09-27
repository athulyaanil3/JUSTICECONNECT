import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdvocateClerkJudgeAssistTab extends StatefulWidget {
  const AdvocateClerkJudgeAssistTab({Key? key}) : super(key: key);

  @override
  _AdvocateClerkJudgeAssistTabState createState() => _AdvocateClerkJudgeAssistTabState();
}

class _AdvocateClerkJudgeAssistTabState extends State<AdvocateClerkJudgeAssistTab> {
  final List<Map<String, dynamic>> _files = [
    {'case': '2026-001 (State vs John Doe)', 'prepared': false},
    {'case': '2026-002 (Property Dispute)', 'prepared': true},
    {'case': '2026-003 (Civil Appeal)', 'prepared': false},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Prepare Hearing Files',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._files.map((file) => CheckboxListTile(
              title: Text(file['case'], style: GoogleFonts.inter()),
              subtitle: const Text('Arrange all relevant documents for the judge.'),
              value: file['prepared'],
              activeColor: Theme.of(context).primaryColor,
              onChanged: (val) {
                setState(() {
                  file['prepared'] = val;
                });
              },
              secondary: const Icon(Icons.folder_shared),
            )),
        const SizedBox(height: 24),
        Text(
          'Update Proceedings (Live)',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Case: 2026-001 (Ongoing)', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Type court proceedings, judge notes, or orders here...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Proceedings updated successfully')),
                      );
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save to Case File'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
