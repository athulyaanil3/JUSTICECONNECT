import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdvocateClerkVerificationTab extends StatefulWidget {
  const AdvocateClerkVerificationTab({Key? key}) : super(key: key);

  @override
  _AdvocateClerkVerificationTabState createState() => _AdvocateClerkVerificationTabState();
}

class _AdvocateClerkVerificationTabState extends State<AdvocateClerkVerificationTab> {
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
              Tab(text: 'Case Preparation'),
              Tab(text: 'Document Check'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildCaseVerificationList(),
                _buildDocumentValidationList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaseVerificationList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Case #2026-00${index + 1}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Chip(label: Text('Under Prep'), backgroundColor: Colors.orangeAccent),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Assigned by: Your Lawyer', style: GoogleFonts.inter(color: Colors.grey[700])),
                Text('Type: Civil Dispute', style: GoogleFonts.inter(color: Colors.grey[700])),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature available in full version'))); },
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Request Client Correction', textAlign: TextAlign.center),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature available in full version'))); },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        child: const Text('Ready for Review', textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocumentValidationList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 2,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
                        const SizedBox(width: 8),
                        Text('Affidavit_${index+1}.pdf', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const Chip(label: Text('Pending'), backgroundColor: Colors.yellowAccent),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Uploaded by: Client', style: GoogleFonts.inter(color: Colors.grey[700])),
                Text('Case: 2026-00${index+1}', style: GoogleFonts.inter(color: Colors.grey[700])),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature available in full version'))); },
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Request Correction', textAlign: TextAlign.center),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature available in full version'))); },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        child: const Text('Approve Document', textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
