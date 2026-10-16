import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'pending_approval_screen.dart';

class AdvocateClerkVerificationScreen extends StatefulWidget {
  const AdvocateClerkVerificationScreen({super.key});

  @override
  State<AdvocateClerkVerificationScreen> createState() => _AdvocateClerkVerificationScreenState();
}

class _AdvocateClerkVerificationScreenState extends State<AdvocateClerkVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _empIdController = TextEditingController();
  final _lawyerUrlController = TextEditingController();
  
  String _selectedDistrict = 'Thiruvananthapuram';
  bool _hasUploadedDocument = false;
  String _mockDocumentName = '';
  File? _selectedFile;
  bool _isSubmitting = false;

  final List<String> _keralaDistricts = [
    'Thiruvananthapuram', 'Kollam', 'Pathanamthitta', 'Alappuzha', 
    'Kottayam', 'Idukki', 'Ernakulam', 'Thrissur', 'Palakkad', 
    'Malappuram', 'Kozhikode', 'Wayanad', 'Kannur', 'Kasaragod'
  ];

  @override
  void dispose() {
    _empIdController.dispose();
    _lawyerUrlController.dispose();
    super.dispose();
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_hasUploadedDocument) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your Appointment Letter / ID'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_lawyerUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the Lawyer\'s Profile URL'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String username = _lawyerUrlController.text.trim();
      if (username.contains('justiceconnect.in/lawyer/')) {
        username = username.split('justiceconnect.in/lawyer/').last.replaceAll('/', '');
      }

      final lawyerQuery = await Supabase.instance.client
          .from('profiles')
          .select('id, username')
          .eq('role', 'Lawyer')
          .ilike('username', username)
          .maybeSingle();

      if (lawyerQuery == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find a Lawyer with that URL. Please check the link.'), backgroundColor: Colors.red),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final lawyerId = lawyerQuery['id'];

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final userMeta = user.userMetadata;
        final clerkUsername = (userMeta != null && userMeta.containsKey('username')) 
            ? userMeta['username'] 
            : 'Unknown';

        String? uploadedDocName;
        if (_selectedFile != null) {
          final originalName = _selectedFile!.path.split(Platform.pathSeparator).last.replaceAll(' ', '_');
          uploadedDocName = 'clerk_verification_${user.id}_$originalName';
          try {
            final fileBytes = await _selectedFile!.readAsBytes();
            await Supabase.instance.client.storage.from('documents').uploadBinary(
              uploadedDocName, 
              fileBytes,
              fileOptions: const FileOptions(upsert: true),
            );
          } catch (storageErr) {
            debugPrint('Storage upload non-fatal warning: $storageErr. Proceeding with registration.');
          }
        }

        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'username': clerkUsername,
          'role': 'Advocate Clerk',
          'email': user.email,
          'court_district': _selectedDistrict,
          'is_verified': null,
          'associated_lawyer_id': lawyerId,
          'verification_document': ?uploadedDocName,
        });

        // Notify the lawyer
        await Supabase.instance.client.from('app_notifications').insert({
          'target_user': lawyerQuery['username'],
          'title': 'New Clerk Request',
          'message': '$clerkUsername has requested to join as your Advocate Clerk. Tap to review their verification document and details.',
          'is_read': false,
          'action_payload': user.id,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification details submitted successfully!')),
      );
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PendingApprovalScreen()),
      );
    } catch (e) {
      debugPrint('Error saving verification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _pickDocument() async {
    try {
      PlatformFile? result = await FilePicker.pickFile(
        type: FileType.any,
      );

      if (result != null && result.path != null) {
        setState(() {
          _hasUploadedDocument = true;
          _mockDocumentName = result.name;
          _selectedFile = File(result.path!);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document selected successfully!')));
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advocate Clerk Verification'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Court Assignment Details',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please provide your employee and court details in Kerala to verify your account.',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              
              TextFormField(
                controller: _empIdController,
                decoration: const InputDecoration(
                  labelText: 'Government Employee ID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (value) => value!.isEmpty ? 'Required field' : null,
              ),
              const SizedBox(height: 20),
              
              DropdownButtonFormField<String>(
                initialValue: _selectedDistrict,
                decoration: const InputDecoration(
                  labelText: 'Court District',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
                items: _keralaDistricts.map((String district) {
                  return DropdownMenuItem<String>(
                    value: district,
                    child: Text(district),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedDistrict = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _lawyerUrlController,
                decoration: const InputDecoration(
                  labelText: 'Supervising Lawyer Profile URL',
                  hintText: 'e.g. justiceconnect.in/lawyer/johndoe',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                validator: (value) => value!.isEmpty ? 'Required field' : null,
              ),
              const SizedBox(height: 24),
              
              Text(
                'Appointment Letter / ID',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload a scanned copy of your official ID or appointment letter',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[50],
                ),
                child: Column(
                  children: [
                    if (_hasUploadedDocument) ...[
                      const Icon(Icons.check_circle, color: Colors.green, size: 40),
                      const SizedBox(height: 8),
                      Text('Document Uploaded', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      Text(_mockDocumentName, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _pickDocument,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Change Document'),
                      ),
                    ] else ...[
                      const Icon(Icons.upload_file, color: Colors.grey, size: 40),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _pickDocument,
                        icon: const Icon(Icons.upload),
                        label: const Text('Select Document'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Submit Verification', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
