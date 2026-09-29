import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../models/case_document.dart';
import '../../../services/evidence_encryption_service.dart';
import '../../../services/pattern_verification_service.dart';

class SecureEvidenceViewer extends StatefulWidget {
  final String caseId;

  const SecureEvidenceViewer({Key? key, required this.caseId}) : super(key: key);

  @override
  _SecureEvidenceViewerState createState() => _SecureEvidenceViewerState();
}

class _SecureEvidenceViewerState extends State<SecureEvidenceViewer> {
  final _supabase = Supabase.instance.client;
  final _encryptionService = EvidenceEncryptionService();
  List<CaseDocument> _documents = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _secureScreen(true);
    _fetchEvidence();
  }

  @override
  void dispose() {
    _secureScreen(false);
    super.dispose();
  }

  Future<void> _secureScreen(bool secure) async {
    if (Platform.isAndroid) {
      const channel = MethodChannel('com.justiceconnect/secure_screen');
      try {
        if (secure) {
          await channel.invokeMethod('secure');
        } else {
          await channel.invokeMethod('unsecure');
        }
      } catch (e) {
        debugPrint('Failed to secure screen: $e');
      }
    }
  }

  Future<void> _fetchEvidence() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase
          .from('case_documents')
          .select()
          .eq('case_id', widget.caseId)
          .eq('document_type', 'Evidence Package')
          .order('created_at', ascending: false);
      setState(() {
        _documents = res.map((d) => CaseDocument.fromJson(d)).toList();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load evidence: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _viewEvidence(CaseDocument doc) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Requesting authorization & decrypting evidence...'),
          ],
        ),
      ),
    );

    try {
      // 🔐 Pattern Verification Before Viewing 🔐
      final isAuthenticated = await PatternVerificationService.authenticate(
        context: context,
        reason: 'Please draw your secure pattern to authorize viewing this highly secure evidence.',
        userKey: _supabase.auth.currentUser?.email,
      );

      if (!isAuthenticated) {
        if (mounted) Navigator.pop(context); // Close loading dialog
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication failed. Evidence not decrypted.')));
        return;
      }

      // 1. Get Session for Edge Function Authorization
      final session = _supabase.auth.currentSession;
      if (session == null) throw Exception('Not authenticated');

      // 2. Call Edge Function to get Key & Nonce safely
      final response = await _supabase.functions.invoke(
        'get-case-evidence-access',
        body: {'case_id': widget.caseId, 'document_id': doc.id},
      );

      if (response.status != 200) {
        throw Exception('Authorization failed: ${response.data}');
      }

      final keyBase64 = response.data['key'] as String;
      final nonceBase64 = response.data['nonce'] as String;

      // 3. Download encrypted file from storage
      final bytes = await _supabase.storage.from('case-evidence').download(doc.storagePath!);
      
      final tempDir = await getTemporaryDirectory();
      final tempEncryptedFile = File('${tempDir.path}/${doc.id}.enc');
      await tempEncryptedFile.writeAsBytes(bytes);

      // 4. Decrypt evidence package
      final decryptedFiles = await _encryptionService.decryptEvidencePackage(
        tempEncryptedFile,
        keyBase64,
        nonceBase64,
      );

      // Cleanup encrypted temp file
      if (await tempEncryptedFile.exists()) {
        await tempEncryptedFile.delete();
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showExtractedFiles(decryptedFiles);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Evidence access error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Access Denied or Decryption Failed: $e'), backgroundColor: Colors.red));
    }
  }

  void _showExtractedFiles(List<File> files) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('🔐 Secure Evidence', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _encryptionService.cleanupDecryptedFiles(files);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Files are stored temporarily on your device and will be deleted when closed.', style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
              const Divider(height: 32),
              Expanded(
                child: ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final fileName = file.path.split(Platform.pathSeparator).last;
                    return ListTile(
                      leading: const Icon(Icons.description, color: Colors.blue),
                      title: Text(fileName),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () async {
                        final ext = fileName.toLowerCase();
                        if (ext.endsWith('.jpg') || ext.endsWith('.png') || ext.endsWith('.jpeg')) {
                          showDialog(
                            context: context,
                            builder: (ctx) => Dialog(
                              child: Stack(
                                children: [
                                  InteractiveViewer(child: Image.file(file)),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.black, size: 30),
                                      onPressed: () => Navigator.pop(ctx),
                                    ),
                                  )
                                ]
                              ),
                            ),
                          );
                        } else {
                          final result = await OpenFilex.open(file.path);
                          if (result.type != ResultType.done && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open file: ${result.message}')));
                          }
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      // Cleanup when bottom sheet is dismissed
      _encryptionService.cleanupDecryptedFiles(files);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
      );
    }

    if (_documents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text('No secure evidence uploaded for this case.', style: GoogleFonts.inter(color: Colors.grey)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final doc = _documents[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.lock, color: Colors.teal),
            title: Text(doc.documentName, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            subtitle: Text('Uploaded: ${doc.createdAt.toLocal().toString().split('.')[0]}'),
            trailing: ElevatedButton(
              onPressed: () => _viewEvidence(doc),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              child: const Text('View Evidence'),
            ),
          ),
        );
      },
    );
  }
}
