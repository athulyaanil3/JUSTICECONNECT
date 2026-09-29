import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/legal_case.dart';
import '../models/case_update.dart';
import 'package:uuid/uuid.dart';

class LawyerProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<LegalCase> _myCases = [];
  List<LegalCase> get myCases => _myCases;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  LawyerProvider() {
    fetchMyCases();
  }

  Future<void> fetchMyCases() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final res = await _supabase.from('cases').select().eq('lawyer_id', userId).order('created_at', ascending: false);
      _myCases = res.map((c) => LegalCase.fromJson(c)).toList();
    } catch (e) {
      debugPrint('Error fetching lawyer cases: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitNewCaseFile(String title, String category, String description, String clientId, {String? advocateClerkId}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      String? actualCitizenId;
      if (clientId.isNotEmpty) {
        final profileQuery = await _supabase.from('profiles').select('id').ilike('username', clientId).maybeSingle();
        if (profileQuery != null && profileQuery['id'] != null) {
          actualCitizenId = profileQuery['id'];
        }
      }

      // Auto-assign the specific clerk associated with this lawyer
      String? actualClerkId = advocateClerkId;
      if (actualClerkId == null) {
        final clerkQuery = await _supabase.from('profiles')
            .select('id')
            .eq('role', 'Advocate Clerk')
            .eq('associated_lawyer_id', userId)
            .eq('is_verified', true) // Only assign approved clerks
            .limit(1)
            .maybeSingle();
        if (clerkQuery != null && clerkQuery['id'] != null) {
          actualClerkId = clerkQuery['id'];
        }
      }

      final res = await _supabase.from('cases').insert({
        'title': title,
        'category': category,
        'description': description,
        'lawyer_id': userId,
        'user_id': actualCitizenId,
        'status': 'Submitted',
        'case_number': '',
        if (actualClerkId != null) 'advocate_clerk_id': actualClerkId,
      }).select().single();

      final newCase = LegalCase.fromJson(res);

      // Add initial update
      await _supabase.from('case_updates').insert({
        'case_id': newCase.id,
        'update_type': 'Case File Submitted',
        'description': 'Case file submitted by lawyer for verification.',
        'created_by': userId,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      if (actualClerkId != null) {
        await _supabase.from('case_updates').insert({
          'case_id': newCase.id,
          'update_type': 'Advocate Clerk Assigned',
          'description': 'Lawyer has automatically assigned their Advocate Clerk to assist with this case.',
          'created_by': userId,
          'created_at': DateTime.now().toIso8601String(),
        });
        
        await _supabase.from('app_notifications').insert({
          'id': Uuid().v4(),
          'target_user': actualClerkId,
          'title': 'New Case Assigned',
          'message': 'You have been automatically assigned to assist with a new case by your Lawyer.',
          'action_payload': newCase.id,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      await fetchMyCases();
    } catch (e) {
      debugPrint('Error submitting new case: $e');
    }
  }

  Future<void> addOfficialCase(
    String title,
    String category,
    String description,
    String citizenId,
    String caseNumber,
    String courtName,
    String petitioner,
    String respondent,
    DateTime nextHearingDate,
    String purpose,
  ) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      String? actualCitizenId;
      if (citizenId.isNotEmpty) {
        final profileQuery = await _supabase.from('profiles').select('id').ilike('username', citizenId).maybeSingle();
        if (profileQuery != null && profileQuery['id'] != null) {
          actualCitizenId = profileQuery['id'];
        }
      }

      String? actualClerkId;
      final clerkQuery = await _supabase.from('profiles').select('id').eq('role', 'Advocate Clerk').eq('associated_lawyer_id', userId).limit(1).maybeSingle();
      if (clerkQuery != null && clerkQuery['id'] != null) {
        actualClerkId = clerkQuery['id'];
      }

      final res = await _supabase.from('cases').insert({
        'title': title,
        'category': category,
        'description': description,
        'lawyer_id': userId,
        'user_id': actualCitizenId,
        'status': 'Ongoing',
        'case_number': caseNumber,
        'court_name': courtName,
        'petitioner': petitioner,
        'respondent': respondent,
        'next_hearing_date': nextHearingDate.toIso8601String(),
        'purpose': purpose,
        if (actualClerkId != null) 'advocate_clerk_id': actualClerkId,
      }).select().single();

      final newCase = LegalCase.fromJson(res);

      await _supabase.from('case_updates').insert({
        'case_id': newCase.id,
        'update_type': 'Official Case Added',
        'description': 'Case officially registered at $courtName (No: $caseNumber). Next hearing: ${nextHearingDate.toIso8601String().substring(0,10)}.',
        'created_by': userId,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (actualCitizenId != null) {
        await _supabase.from('app_notifications').insert({
          'id': Uuid().v4(),
          'target_user': citizenId,
          'title': 'New Case Added',
          'message': 'Your lawyer has added your official case ($caseNumber) to the portal.',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      await fetchMyCases();
    } catch (e) {
      debugPrint('Error adding official case: $e');
    }
  }

  Future<void> updateCaseStatus(String caseId, String newStatus, String description) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Update case status
      await _supabase.from('cases').update({'status': newStatus, 'updated_at': DateTime.now().toIso8601String()}).eq('id', caseId);

      // Add timeline update
      await _supabase.from('case_updates').insert({
        'case_id': caseId,
        'update_type': 'Lawyer Update: $newStatus',
        'description': description,
        'created_by': userId,
        'created_at': DateTime.now().toIso8601String(),
      });

      await fetchMyCases();
    } catch (e) {
      debugPrint('Error updating case status: $e');
    }
  }

  Future<void> deleteCase(String caseId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Optimistically remove from list
      _myCases.removeWhere((c) => c.id == caseId);
      notifyListeners();

      // Delete from Supabase
      // Assuming ON DELETE CASCADE is set for case_updates, etc.
      // If not, we might need to delete case_updates first, but Supabase handles cascading usually.
      await _supabase.from('cases').delete().eq('id', caseId).eq('lawyer_id', userId);
      
      await fetchMyCases();
    } catch (e) {
      debugPrint('Error deleting case: $e');
      await fetchMyCases(); // Revert on failure
    }
  }

  Future<void> updateOfficialCaseDetails(
    String caseId, 
    String caseNumber,
    String courtName,
    String petitioner,
    String respondent,
    DateTime nextHearingDate,
    String purpose,
  ) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('cases').update({
        'case_number': caseNumber,
        'status': 'Ongoing',
        'court_name': courtName,
        'petitioner': petitioner,
        'respondent': respondent,
        'next_hearing_date': nextHearingDate.toIso8601String(),
        'purpose': purpose,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', caseId);

      await _supabase.from('case_updates').insert({
        'case_id': caseId,
        'update_type': 'Official Case Registered',
        'description': 'Case officially registered at $courtName (No: $caseNumber). Next hearing: ${nextHearingDate.toIso8601String().substring(0,10)}.',
        'created_by': userId,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Notify User
      final caseData = await _supabase.from('cases').select('user_id').eq('id', caseId).maybeSingle();
      if (caseData != null && caseData['user_id'] != null) {
        String targetUserId = caseData['user_id'];
        
        String targetUsername = targetUserId;
        final profileQuery = await _supabase.from('profiles').select('username').eq('id', targetUserId).maybeSingle();
        if (profileQuery != null && profileQuery['username'] != null) {
          targetUsername = profileQuery['username'];
        }

        await _supabase.from('app_notifications').insert({
          'id': Uuid().v4(),
          'target_user': targetUsername,
          'title': 'Case Officially Registered',
          'message': 'Your case has been officially registered at $courtName (No: $caseNumber).',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      await fetchMyCases();
    } catch (e) {
      debugPrint('Error updating official case details: $e');
    }
  }

  Future<List<CaseUpdate>> fetchCaseUpdates(String caseId) async {
    try {
      final res = await _supabase.from('case_updates').select().eq('case_id', caseId).order('created_at', ascending: true);
      return res.map((u) => CaseUpdate.fromJson(u)).toList();
    } catch (e) {
      debugPrint('Error fetching updates: $e');
      return [];
    }
  }

  Future<void> assignAdvocateClerk(String caseId, String clerkId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('cases').update({
        'advocate_clerk_id': clerkId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', caseId);

      await _supabase.from('case_updates').insert({
        'case_id': caseId,
        'update_type': 'Advocate Clerk Assigned',
        'description': 'Lawyer has assigned an Advocate Clerk to assist with this case.',
        'created_by': userId,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Notify the assigned clerk
      await _supabase.from('app_notifications').insert({
        'id': Uuid().v4(),
        'target_user': clerkId,
        'title': 'New Case Assigned',
        'message': 'You have been assigned to assist with a new case by your Lawyer.',
        'action_payload': caseId,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      await fetchMyCases();
    } catch (e) {
      debugPrint('Error assigning advocate clerk: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchAvailableClerks() async {
    try {
      // In a full implementation, we'd filter by an association table (e.g. lawyer_clerks).
      // For this mini-project, we fetch all users with role 'Advocate Clerk' and approval_status 'approved'.
      final res = await _supabase.from('profiles').select('id, username').eq('role', 'Advocate Clerk');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching clerks: $e');
      return [];
    }
  }
}
