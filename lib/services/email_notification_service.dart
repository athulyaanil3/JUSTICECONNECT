import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailNotificationService {
  static final _supabase = Supabase.instance.client;
  static const String senderEmail = 'justiceconnect2026@gmail.com';

  /// Sends a case update email notification to the citizen/user associated with the case.
  static Future<void> sendCaseUpdateEmail({
    required String caseId,
    required String updateType,
    required String description,
    String? role, // 'Lawyer' or 'Advocate Clerk'
    String? updaterName,
  }) async {
    try {
      // 1. Fetch case details from database
      final caseRow = await _supabase
          .from('cases')
          .select('user_id, case_number, case_title, title, court_name')
          .eq('id', caseId)
          .maybeSingle();

      if (caseRow == null || caseRow['user_id'] == null) {
        debugPrint('EmailService: Case or user_id not found for case $caseId');
        return;
      }

      final userId = caseRow['user_id'] as String;
      final caseNumber = (caseRow['case_number'] ?? '').toString();
      final caseTitle = (caseRow['case_title'] ?? caseRow['title'] ?? 'Legal Matter').toString();
      final courtName = (caseRow['court_name'] ?? 'Court of Law').toString();

      // 2. Fetch citizen/user profile details
      Map<String, dynamic>? profileRow;
      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(userId);
      if (isUuid) {
        profileRow = await _supabase
            .from('profiles')
            .select('email, username')
            .eq('id', userId)
            .maybeSingle();
      }
      if (profileRow == null) {
        profileRow = await _supabase
            .from('profiles')
            .select('email, username')
            .or('username.ilike.$userId,email.ilike.$userId')
            .maybeSingle();
      }
      if (profileRow == null && caseRow['petitioner'] != null) {
        final pet = caseRow['petitioner'].toString();
        profileRow = await _supabase
            .from('profiles')
            .select('email, username')
            .ilike('username', pet)
            .maybeSingle();
      }

      final userEmail = profileRow?['email'] as String?;
      final userName = (profileRow?['username'] ?? 'Valued Citizen').toString();

      if (userEmail == null || userEmail.trim().isEmpty || !userEmail.contains('@')) {
        debugPrint('EmailService: User $userId does not have a registered email address.');
        return;
      }

      // 3. Prepare Email Details
      final nowFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      final updater = updaterName ?? role ?? 'Legal Representative';
      final subject = 'JusticeConnect: Case Update - $caseTitle ${caseNumber.isNotEmpty ? '($caseNumber)' : ''}'.trim();

      final messageBody = '''
Dear $userName,

You have a new case update regarding your legal matter on JusticeConnect.

Case Details:
• Title: $caseTitle
• Case Number: ${caseNumber.isEmpty ? 'Pending Number' : caseNumber}
• Court: $courtName

Update Details:
• Type: $updateType
• Description: $description
• Recorded By: $updater
• Date & Time: $nowFormatted

You can view complete proceedings, documents, and updates inside the JusticeConnect app.

Best regards,
JusticeConnect Team
Support: $senderEmail
''';

      debugPrint('EmailService: Dispatching email to $userEmail for update "$updateType"...');

      // 4. Dispatch Email via FormSubmit AJAX service
      final response = await http.post(
        Uri.parse('https://formsubmit.co/ajax/$userEmail'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          '_subject': subject,
          '_replyto': senderEmail,
          'recipient_name': userName,
          'case_title': caseTitle,
          'case_number': caseNumber.isEmpty ? 'N/A' : caseNumber,
          'court': courtName,
          'update_type': updateType,
          'updated_by': updater,
          'timestamp': nowFormatted,
          'message': messageBody,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('EmailService: Email successfully sent to $userEmail (Status: ${response.statusCode})');
      } else {
        debugPrint('EmailService: Email dispatch response: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('EmailService: Error sending case update email: $e');
    }
  }
}
