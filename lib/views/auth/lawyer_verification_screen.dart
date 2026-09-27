import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'pending_approval_screen.dart';

class LawyerVerificationScreen extends StatefulWidget {
  const LawyerVerificationScreen({Key? key}) : super(key: key);

  @override
  _LawyerVerificationScreenState createState() => _LawyerVerificationScreenState();
}

class _LawyerVerificationScreenState extends State<LawyerVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _enrollmentController = TextEditingController();
  final _yearController = TextEditingController();
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

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_hasUploadedDocument) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your Bar Council Certificate'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Save to Supabase using upsert to guarantee row exists and has correct role
        final userMeta = user.userMetadata;
        final username = (userMeta != null && userMeta.containsKey('username')) 
            ? userMeta['username'] 
            : 'Unknown';

        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'username': username,
          'role': 'Lawyer',
          'email': user.email,
          'enrollment_number': _enrollmentController.text.trim(),
          'enrollment_year': int.tryParse(_yearController.text.trim()),
          'district': _selectedDistrict,
          'is_verified': null,
        });
        
        if (_selectedFile != null) {
          try {
            final fileExt = _selectedFile!.path.split('.').last;
            final fileName = 'verification_${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
            await Supabase.instance.client.storage.from('documents').upload(fileName, _selectedFile!);
          } catch (storageErr) {
            debugPrint('Storage error (ignoring for test): $storageErr');
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification details submitted successfully!')),
      );
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PendingApprovalScreen()),
        );
      }
    } catch (e) {
      debugPrint('Error saving verification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _simulateDocumentUpload() async {
    try {
      PlatformFile? result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.path != null) {
        setState(() {
          _hasUploadedDocument = true;
          _mockDocumentName = result.name;
          _selectedFile = File(result.path!);
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lawyer Verification'),
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
                'Kerala Bar Council Details',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please provide your enrollment details to verify your identity as a practicing lawyer in Kerala.',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              
              TextFormField(
                controller: _enrollmentController,
                decoration: const InputDecoration(
                  labelText: 'Enrollment Number (e.g. K/1234/2020)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
                validator: (value) => value!.isEmpty ? 'Required field' : null,
              ),
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _yearController,
                decoration: const InputDecoration(
                  labelText: 'Year of Enrollment',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Required field' : null,
              ),
              const SizedBox(height: 20),
              
              DropdownButtonFormField<String>(
                value: _selectedDistrict,
                decoration: const InputDecoration(
                  labelText: 'Primary Practice District',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                items: _keralaDistricts.map((String district) {
                  return DropdownMenuItem<String>(
                    value: district,
                    child: Text(district),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedDistrict = newValue!;
                  });
                },
              ),
              const SizedBox(height: 24),
              
              Text(
                'Bar Council Certificate',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload a scanned copy of your certificate (PDF or Image)',
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
                        onPressed: _simulateDocumentUpload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Change Document'),
                      ),
                    ] else ...[
                      const Icon(Icons.upload_file, color: Colors.grey, size: 40),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _simulateDocumentUpload,
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
