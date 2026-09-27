import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/legal_case.dart';
import '../models/hearing.dart';
import '../models/case_document.dart';
import '../models/petition.dart';
import '../models/case_update.dart';
import 'dart:math';
import 'package:uuid/uuid.dart';

class AdvocateClerkProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<LegalCase> _cases = [];
  List<Hearing> _hearings = [];

  List<LegalCase> get cases => _cases;
  List<Hearing> get hearings => _hearings;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  AdvocateClerkProvider() {
    _init();
  }

  Future<void> _init() async {
    await fetchAllData();
  }

  Future<void> fetchAllData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Fetch Cases assigned to this Advocate Clerk
      final casesRes = await _supabase.from('cases').select().eq('advocate_clerk_id', currentUserId).order('created_at', ascending: false);
      _cases = casesRes.map((c) => LegalCase.fromJson(c)).toList();

      // Fetch Hearings for these cases
      if (_cases.isNotEmpty) {
        final caseIds = _cases.map((c) => c.id).toList();
        final hearingsRes = await _supabase.from('hearings').select().inFilter('case_id', caseIds).order('hearing_date', ascending: true);
        _hearings = hearingsRes.map((h) => Hearing.fromJson(h)).toList();
      } else {
        _hearings = [];
      }

    } catch (e) {
      debugPrint('Error fetching advocate clerk data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Document Verification ---
  Future<List<CaseDocument>> fetchCaseDocuments(String caseId) async {
    try {
      final res = await _supabase.from('documents').select().eq('case_id', caseId);
      return res.map((d) => CaseDocument.fromJson(d)).toList();
    } catch (e) {
      debugPrint('Error fetching documents: $e');
      return [];
    }
  }

  Future<Petition?> fetchPetition(String caseId) async {
    try {
      final res = await _supabase.from('petitions').select().eq('case_id', caseId).maybeSingle();
      if (res != null) {
        return Petition.fromJson(res);
      }
    } catch (e) {
      debugPrint('Error fetching petition: $e');
    }
    return null;
  }

  Future<void> verifyDocument(String documentId, String status, String remarks) async {
    try {
      await _supabase.from('documents').update({
        'verification_status': status,
        'remarks': remarks,
      }).eq('id', documentId);
    } catch (e) {
      debugPrint('Error verifying document: $e');
    }
  }

  // --- Case File Preparation Workflow ---

  Future<void> markCorrectionRequired(String caseId, String reason, String lawyerId) async {
    try {
      await _supabase.from('cases').update({
        'status': 'Correction Required',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', caseId);
      
      // Notify Lawyer
      await _sendNotification(lawyerId, 'Document Correction Required', 'Missing or invalid documents: $reason', caseId);
      await addCaseUpdate(caseId, 'Correction Required', reason);
      
      await fetchAllData();
    } catch (e) {
      debugPrint('Error marking correction: $e');
    }
  }

  Future<void> markReadyForLawyerReview(String caseId, String lawyerId) async {
    try {
      await _supabase.from('cases').update({
        'status': 'Ready for Lawyer Review',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', caseId);
      
      // Notify Lawyer
      await _sendNotification(lawyerId, 'Case Ready for Review', 'The document package has been prepared and is ready for your review.', caseId);
      await addCaseUpdate(caseId, 'Ready for Lawyer Review', 'Advocate clerk has organized and checked all documents.');
      
      await fetchAllData();
    } catch (e) {
      debugPrint('Error updating case: $e');
    }
  }

  Future<void> coordinateFiling(String caseId, String caseNumber, String lawyerId, String userId) async {
    try {
      await _supabase.from('cases').update({
        'status': 'Filed',
        'case_number': caseNumber,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', caseId);

      await addCaseUpdate(caseId, 'Case Filed', 'Case has been officially filed. Ref: $caseNumber');

      await _sendNotification(lawyerId, 'Case Filed', 'The case has been filed successfully.', caseId);
      await _sendNotification(userId, 'Case Filed', 'Your case has been filed with the court.', caseId);

      await fetchAllData();
    } catch (e) {
      debugPrint('Error filing case: $e');
    }
  }

  // --- Case Updates ---
  Future<List<CaseUpdate>> fetchCaseUpdates(String caseId) async {
    try {
      final res = await _supabase.from('case_updates').select().eq('case_id', caseId).order('created_at', ascending: true);
      return res.map((u) => CaseUpdate.fromJson(u)).toList();
    } catch (e) {
      debugPrint('Error fetching updates: $e');
      return [];
    }
  }

  Future<void> addCaseUpdate(String caseId, String updateType, String description) async {
    try {
      await _supabase.from('case_updates').insert({
        'case_id': caseId,
        'update_type': updateType,
        'description': description,
        'created_by': _supabase.auth.currentUser?.id,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error adding case update: $e');
    }
  }

  Future<void> updateCaseStatusAndAddUpdate(String caseId, String newStatus, String updateType, String description) async {
    try {
      await _supabase.from('cases').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', caseId);

      await addCaseUpdate(caseId, updateType, description);
      
      // Notify the User (Without exposing clerk identity)
      final caseQuery = await _supabase.from('cases').select('user_id').eq('id', caseId).maybeSingle();
      if (caseQuery != null && caseQuery['user_id'] != null) {
        await _sendNotification(
          caseQuery['user_id'], 
          'Case Update: $updateType', 
          'Status changed to $newStatus. $description', 
          caseId
        );
      }
      
      await fetchAllData();
    } catch (e) {
      debugPrint('Error updating case status and timeline: $e');
    }
  }

  // --- Administrative Closure ---
  Future<void> sendCustomUpdateToUser(String caseId, String userId, String updateTitle, String updateDescription) async {
    try {
      await _sendNotification(userId, 'Case Update: $updateTitle', updateDescription, caseId);
      await addCaseUpdate(caseId, updateTitle, updateDescription);
      await fetchAllData();
    } catch (e) {
      debugPrint('Error sending custom update: $e');
    }
  }

  Future<void> addClosureRemarks(String caseId, String reason, String newStatus, String lawyerId, String userId) async {
    try {
      await _supabase.from('cases').update({
        'status': newStatus, // 'Closed' or 'Dismissed'
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', caseId);

      await addCaseUpdate(caseId, 'Administrative Closure', 'Closure processed by clerk: $reason');

      await fetchAllData();
    } catch (e) {
      debugPrint('Error closing case administratively: $e');
    }
  }

  // --- Hearings ---
  Future<void> recordHearingInformation(String caseId, DateTime date, String timeStr, String remarks, bool notifyLawyer) async {
    try {
      await _supabase.from('hearings').insert({
        'case_id': caseId,
        'hearing_date': date.toIso8601String(),
        'hearing_time': timeStr,
        'status': 'Scheduled',
        'remarks': 'Recorded by Advocate Clerk: $remarks',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      final caseQuery = await _supabase.from('cases').select('user_id, lawyer_id').eq('id', caseId).maybeSingle();
      if (caseQuery != null) {
        if (notifyLawyer) {
          await _sendNotification(caseQuery['lawyer_id'], 'Hearing Scheduled', 'A hearing has been recorded for your case.', caseId);
        }
        await _sendNotification(caseQuery['user_id'], 'Hearing Scheduled', 'A hearing has been scheduled for your case.', caseId);
      }

      await _supabase.from('cases').update({'status': 'Hearing Scheduled'}).eq('id', caseId);
      await addCaseUpdate(caseId, 'Hearing Recorded', 'Hearing date recorded for ${date.toString().substring(0, 10)} at $timeStr. $remarks');

      await fetchAllData();
    } catch (e) {
      debugPrint('Error scheduling hearing: $e');
    }
  }

  Future<void> updateHearingStatus(String hearingId, String caseId, String newStatus, String remarks) async {
    try {
      await _supabase.from('hearings').update({
        'status': newStatus,
        'remarks': remarks,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', hearingId);
      
      final caseQuery = await _supabase.from('cases').select('user_id, lawyer_id').eq('id', caseId).maybeSingle();
      if (caseQuery != null) {
        String msg = '';
        if (newStatus == 'Completed') msg = 'The scheduled hearing for your case has been marked as completed.';
        else msg = 'The hearing details for your case have been updated.';

        await _sendNotification(caseQuery['lawyer_id'], 'Hearing Updated', msg, caseId);
        await _sendNotification(caseQuery['user_id'], 'Hearing Updated', msg, caseId);
      }

      await fetchAllData();
    } catch (e) {
      debugPrint('Error updating hearing: $e');
    }
  }

  // --- Internal Notification Helper ---
  Future<void> _sendNotification(String userId, String title, String message, String relatedId) async {
    try {
      // Find the username from the userId
      String targetUser = userId;
      final profileQuery = await _supabase.from('profiles').select('username').eq('id', userId).maybeSingle();
      if (profileQuery != null && profileQuery['username'] != null) {
        targetUser = profileQuery['username'];
      }

      await _supabase.from('app_notifications').insert({
        'id': Uuid().v4(),
        'target_user': targetUser,
        'title': title,
        'message': message,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error sending notification to $userId: $e');
    }
  }
}

