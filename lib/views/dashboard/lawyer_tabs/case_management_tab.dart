import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../controllers/lawyer_provider.dart';
import '../../../models/legal_case.dart';
import '../chat/filing_chat_screen.dart';
import '../../shared/secure_evidence_viewer.dart';

class CaseManagementTab extends StatefulWidget {
  const CaseManagementTab({Key? key}) : super(key: key);

  @override
  _CaseManagementTabState createState() => _CaseManagementTabState();
}

class _CaseManagementTabState extends State<CaseManagementTab> {
  final List<String> _caseCategories = [
    'Civil', 'Criminal', 'Family Law', 'Corporate', 'Real Estate', 
    'Labor & Employment', 'Tax', 'Constitutional', 'Intellectual Property', 
    'Immigration', 'Bankruptcy', 'Personal Injury', 'Environmental', 
    'Medical Malpractice', 'General'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LawyerProvider>(context, listen: false).fetchMyCases();
    });
  }

  void _showAddNewCaseDialog(BuildContext context) {
    final titleController = TextEditingController();
    final categoryController = TextEditingController();
    final descController = TextEditingController();
    final clientController = TextEditingController();
    final caseNumberController = TextEditingController();
    final courtNameController = TextEditingController();
    final petitionerController = TextEditingController();
    final respondentController = TextEditingController();
    final purposeController = TextEditingController();
    DateTime? selectedDate;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Official Case'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: caseNumberController, decoration: const InputDecoration(labelText: 'Case Number', hintText: 'e.g. WP(C) 123/2026')),
                  const SizedBox(height: 12),
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return _caseCategories;
                      }
                      return _caseCategories.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      categoryController.text = selection;
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      controller.addListener(() {
                        categoryController.text = controller.text;
                      });
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(labelText: 'Case Category', hintText: 'Type or select category'),
                      );
                    },
                  ),
                  TextField(controller: clientController, decoration: const InputDecoration(labelText: 'Client Username (Optional)', hintText: 'e.g. johndoe')),
                  TextField(controller: courtNameController, decoration: const InputDecoration(labelText: 'Court Name', hintText: 'e.g. High Court')),
                  TextField(controller: petitionerController, decoration: const InputDecoration(labelText: 'Petitioner Name')),
                  TextField(controller: respondentController, decoration: const InputDecoration(labelText: 'Respondent Name')),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(selectedDate == null ? 'Select Next Hearing Date' : 'Next Hearing: ${selectedDate!.toString().substring(0, 10)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) setState(() => selectedDate = date);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  if (caseNumberController.text.isNotEmpty && selectedDate != null) {
                    setState(() => isSubmitting = true);
                    await Provider.of<LawyerProvider>(context, listen: false).addOfficialCase(
                      caseNumberController.text, // Title
                      categoryController.text.isNotEmpty ? categoryController.text : 'General', // Category
                      'Officially imported case', // Description
                      clientController.text.trim(), // Client ID (Username)
                      caseNumberController.text,
                      courtNameController.text,
                      petitionerController.text,
                      respondentController.text,
                      selectedDate!,
                      'Next Hearing', // Purpose
                    );
                    if (context.mounted) Navigator.pop(ctx);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Case Number and Hearing Date are required.')));
                  }
                },
                child: isSubmitting 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Add Case'),
              )
            ],
          );
        }
      ),
    );
  }

  void _showCaseUpdates(BuildContext context, LegalCase c) async {
    final provider = Provider.of<LawyerProvider>(context, listen: false);
    final updates = await provider.fetchCaseUpdates(c.id);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Timeline: ${c.title}'),
        content: SizedBox(
          width: double.maxFinite,
          child: updates.isEmpty 
            ? const Text('No updates yet.')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: updates.length,
                itemBuilder: (context, index) {
                  final u = updates[index];
                  return ListTile(
                    leading: const Icon(Icons.history, color: Colors.blue),
                    title: Text(u.updateType, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('${u.description}\n${u.createdAt.toString().substring(0, 16)}', style: GoogleFonts.inter(fontSize: 12)),
                    isThreeLine: true,
                  );
                },
              ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }

  void _confirmDeleteCase(BuildContext context, LegalCase c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Case?'),
        content: const Text('Are you sure you want to permanently delete this case? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await Provider.of<LawyerProvider>(context, listen: false).deleteCase(c.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Case deleted successfully.')));
              }
            },
            child: const Text('Delete'),
          )
        ],
      ),
    );
  }

  void _showSecureEvidence(BuildContext context, LegalCase c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.only(top: 16),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              Text('Case Evidence: ${c.title}', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(child: SecureEvidenceViewer(caseId: c.id)),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Case Management',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddNewCaseDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Case'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Consumer<LawyerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final cases = provider.myCases;

          if (cases.isEmpty) {
            return Center(child: Text('No cases submitted yet.', style: GoogleFonts.inter(color: Colors.grey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: cases.length,
            itemBuilder: (context, index) {
              final c = cases[index];
              return _buildLawyerCaseCard(context, c);
            },
          );
        },
      ),
    );
  }

  void _showAssignClerkDialog(BuildContext context, LegalCase c) async {
    final provider = Provider.of<LawyerProvider>(context, listen: false);
    final clerks = await provider.fetchAvailableClerks();

    if (!context.mounted) return;

    if (clerks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Advocate Clerks available')));
      return;
    }

    String? selectedClerkId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Assign Advocate Clerk'),
            content: DropdownButtonFormField<String>(
              value: selectedClerkId,
              hint: const Text('Select a Clerk'),
              items: clerks.map((clerk) => DropdownMenuItem(
                value: clerk['id'] as String,
                child: Text(clerk['username'] ?? 'Unknown Clerk'),
              )).toList(),
              onChanged: (val) {
                setState(() => selectedClerkId = val);
              },
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedClerkId != null) {
                    await provider.assignAdvocateClerk(c.id, selectedClerkId!);
                    if (context.mounted) Navigator.pop(ctx);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clerk assigned successfully')));
                  }
                },
                child: const Text('Assign'),
              )
            ],
          );
        }
      ),
    );
  }

  void _showAddOfficialDetailsDialog(BuildContext context, LegalCase c) {
    final caseNumberController = TextEditingController(text: c.caseNumber);
    final courtNameController = TextEditingController(text: c.courtName);
    final petitionerController = TextEditingController(text: c.petitioner);
    final respondentController = TextEditingController(text: c.respondent);
    final purposeController = TextEditingController(text: c.purpose);
    DateTime? selectedDate = c.nextHearingDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Official Case Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: caseNumberController,
                    decoration: const InputDecoration(labelText: 'Case Number', hintText: 'e.g. WP(C) 123/2026'),
                  ),
                  TextField(
                    controller: courtNameController,
                    decoration: const InputDecoration(labelText: 'Court Name', hintText: 'e.g. High Court of Kerala'),
                  ),
                  TextField(
                    controller: petitionerController,
                    decoration: const InputDecoration(labelText: 'Petitioner Name'),
                  ),
                  TextField(
                    controller: respondentController,
                    decoration: const InputDecoration(labelText: 'Respondent Name'),
                  ),
                  TextField(
                    controller: purposeController,
                    decoration: const InputDecoration(labelText: 'Purpose', hintText: 'e.g. Admission, Hearing'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: Text(selectedDate == null ? 'Select Next Hearing Date' : 'Next Hearing: ${selectedDate!.toString().substring(0, 10)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setState(() => selectedDate = date);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (caseNumberController.text.isNotEmpty && selectedDate != null) {
                    await Provider.of<LawyerProvider>(context, listen: false).updateOfficialCaseDetails(
                      c.id,
                      caseNumberController.text,
                      courtNameController.text,
                      petitionerController.text,
                      respondentController.text,
                      selectedDate!,
                      purposeController.text,
                    );
                    if (context.mounted) Navigator.pop(ctx);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Case Number and Next Hearing Date are required.')));
                  }
                },
                child: const Text('Save'),
              )
            ],
          );
        }
      ),
    );
  }

  Widget _buildLawyerCaseCard(BuildContext context, LegalCase c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    c.title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    c.status,
                    style: GoogleFonts.inter(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.gavel, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(c.caseNumber.isNotEmpty ? c.caseNumber : 'Unassigned', style: GoogleFonts.inter(color: Colors.grey[700])),
              ],
            ),
            if (c.advocateClerkId.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text('Clerk Assigned', style: GoogleFonts.inter(color: Colors.grey[700], fontStyle: FontStyle.italic, fontSize: 12)),
                ],
              ),
            ],
            const Divider(height: 32),
              Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.spaceAround,
              children: [
                if (c.status == 'Ready for Court' || c.status == 'Ongoing' || c.caseNumber.isEmpty)
                  _buildActionIcon(context, Icons.gavel, 'Official Info', () => _showAddOfficialDetailsDialog(context, c)),
                _buildActionIcon(context, Icons.history, 'Timeline', () => _showCaseUpdates(context, c)),
                _buildActionIcon(context, Icons.security, 'Evidence', () => _showSecureEvidence(context, c), color: Colors.teal),
                _buildActionIcon(context, Icons.assignment_ind, 'Assign Clerk', () => _showAssignClerkDialog(context, c)),
                _buildActionIcon(context, Icons.delete_outline, 'Delete', () => _confirmDeleteCase(context, c), color: Colors.redAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon(BuildContext context, IconData icon, String label, VoidCallback? onTap, {Color? color}) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Column(
        children: [
          Icon(icon, color: color ?? Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: color ?? Colors.grey[700])),
        ],
      ),
    );
  }
}
