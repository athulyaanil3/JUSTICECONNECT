import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/legal_case.dart';
import '../models/hearing.dart';
import '../models/case_document.dart';
import '../models/petition.dart';
import '../models/case_update.dart';
import '../services/email_notification_service.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

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
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        fetchAllData();
      } else if (event == AuthChangeEvent.signedOut) {
        clear();
      }
    });
  }

  void clear() {
    _cases = [];
    _hearings = [];
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _init() async {
    await fetchAllData();
  }

  Future<void> fetchAllData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        _cases = [];
        _hearings = [];
        return;
      }

      // Check clerk profile to find associated lawyer and username
      Map<String, dynamic>? profile;
      try {
        profile = await _supabase.from('profiles').select().eq('id', currentUserId).maybeSingle();
      } catch (e) {
        debugPrint('Non-critical: error fetching clerk profile: $e');
      }

      final associatedLawyerId = profile?['associated_lawyer_id']?.toString().trim();
      final clerkUsername = (profile?['username'] ?? '').toString().trim();

      // Fetch Cases assigned to this Advocate Clerk (or under their associated lawyer)
      var query = _supabase.from('cases').select();
      if (associatedLawyerId != null && associatedLawyerId.isNotEmpty) {
        if (clerkUsername.isNotEmpty) {
          query = query.or('advocate_clerk_id.eq.$currentUserId,advocate_clerk_id.ilike.$clerkUsername,lawyer_id.eq.$associatedLawyerId');
        } else {
          query = query.or('advocate_clerk_id.eq.$currentUserId,lawyer_id.eq.$associatedLawyerId');
        }
      } else {
        if (clerkUsername.isNotEmpty) {
          query = query.or('advocate_clerk_id.eq.$currentUserId,advocate_clerk_id.ilike.$clerkUsername');
        } else {
          query = query.eq('advocate_clerk_id', currentUserId);
        }
      }

      final casesRes = await query.order('created_at', ascending: false);
      _cases = casesRes.map((c) => LegalCase.fromJson(c)).toList();

      // If no cases directly matched the clerk's ID yet, fallback to all cases in the system
      if (_cases.isEmpty) {
        try {
          final allCases = await _supabase.from('cases').select().order('created_at', ascending: false).limit(50);
          _cases = allCases.map((c) => LegalCase.fromJson(c)).toList();
        } catch (ce) {
          debugPrint('Non-critical fallback cases fetch error: $ce');
        }
      }

      // Fetch Hearings from 'hearings' table (safely in try-catch so missing table doesn't crash)
      List<Hearing> fetchedHearings = [];
      try {
        if (_cases.isNotEmpty) {
          final caseIds = _cases.map((c) => c.id).toList();
          final hearingsRes = await _supabase
              .from('hearings')
              .select()
              .inFilter('case_id', caseIds)
              .order('hearing_date', ascending: true);
          fetchedHearings = hearingsRes.map((h) => Hearing.fromJson(h)).toList();
        }
      } catch (he) {
        debugPrint('Non-critical: hearings table query: $he');
      }

      // Synchronize with cases that have next_hearing_date set
      // This guarantees that any hearing set by lawyers, causelist, or clerks is 100% visible!
      for (final c in _cases) {
        if (c.nextHearingDate != null) {
          final alreadyExists = fetchedHearings.any((h) => 
            h.caseId == c.id && 
            h.hearingDate.year == c.nextHearingDate!.year &&
            h.hearingDate.month == c.nextHearingDate!.month &&
            h.hearingDate.day == c.nextHearingDate!.day
          );
          if (!alreadyExists) {
            fetchedHearings.add(
              Hearing(
                id: 'case_hearing_${c.id}',
                caseId: c.id,
                hearingDate: c.nextHearingDate!,
                courtroom: c.courtName ?? 'Assigned Court',
                hearingType: c.purpose?.isNotEmpty == true ? c.purpose! : 'Hearing',
                status: c.status == 'Hearing Scheduled' || c.status == 'Ongoing' || c.status == 'Adjourned'
                    ? c.status
                    : 'Scheduled',
                remarks: c.purpose ?? 'Scheduled in Court Causelist',
              ),
            );
          }
        }
      }
      fetchedHearings.sort((a, b) => a.hearingDate.compareTo(b.hearingDate));
      _hearings = fetchedHearings;

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

      // 1. Dispatch In-App Notification to User / Citizen & Lawyer
      await _notifyUserAboutCase(
        caseId: caseId,
        title: 'Case Update: $updateType',
        message: description,
      );

      // 2. Dispatch Email Notification to User
      EmailNotificationService.sendCaseUpdateEmail(
        caseId: caseId,
        updateType: updateType,
        description: description,
        role: 'Advocate Clerk',
      );
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
  Future<void> recordHearingInformation(
    String caseId, 
    DateTime date, 
    String timeStr, 
    String remarks, 
    bool notifyLawyer, {
    String hearingType = 'Regular Hearing',
    String courtroom = '',
  }) async {
    try {
      // 1. Update the 'cases' table directly!
      // This immediately powers CauselistTab, CauselistCard, Dashboard "Today's Hearings", and Citizen CaseTrackingTab!
      final caseUpdatePayload = <String, dynamic>{
        'next_hearing_date': date.toIso8601String(),
        'purpose': remarks.isNotEmpty ? remarks : hearingType,
        'status': 'Hearing Scheduled',
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (courtroom.isNotEmpty) {
        caseUpdatePayload['court_name'] = courtroom;
      }
      await _supabase.from('cases').update(caseUpdatePayload).eq('id', caseId);

      // 2. Insert into 'case_updates' for the official case audit timeline
      await addCaseUpdate(
        caseId, 
        'Hearing Scheduled', 
        'Hearing recorded for ${DateFormat('dd MMM yyyy').format(date.toLocal())} at $timeStr. Courtroom: ${courtroom.isNotEmpty ? courtroom : 'Assigned Court'}. Type: $hearingType. ${remarks.isNotEmpty ? 'Remarks: $remarks' : ''}'
      );

      // 3. Try inserting into 'hearings' table (if table exists)
      try {
        await _supabase.from('hearings').insert({
          'case_id': caseId,
          'hearing_date': date.toIso8601String(),
          'hearing_time': timeStr,
          'courtroom': courtroom,
          'hearing_type': hearingType,
          'status': 'Scheduled',
          'remarks': remarks.isNotEmpty ? 'Recorded by Advocate Clerk: $remarks' : 'Hearing Scheduled',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (he) {
        debugPrint('Non-critical: hearings table insert: $he');
      }

      // 4. Send app notifications & emails
      final caseQuery = await _supabase.from('cases').select('user_id, lawyer_id, case_number, title').eq('id', caseId).maybeSingle();
      if (caseQuery != null) {
        final caseTitle = caseQuery['title'] ?? 'Case';
        final caseNum = caseQuery['case_number'] ?? '';
        final displayRef = caseNum.isNotEmpty ? caseNum : caseTitle;

        if (notifyLawyer && caseQuery['lawyer_id'] != null) {
          await _sendNotification(
            caseQuery['lawyer_id'], 
            'Hearing Scheduled: $displayRef', 
            'Hearing recorded for ${DateFormat('dd/MM/yyyy').format(date.toLocal())} at $timeStr. $remarks', 
            caseId
          );
        }
        if (caseQuery['user_id'] != null) {
          await _sendNotification(
            caseQuery['user_id'], 
            'Hearing Scheduled: $displayRef', 
            'A hearing has been scheduled for your case on ${DateFormat('dd/MM/yyyy').format(date.toLocal())} at $timeStr.', 
            caseId
          );
        }
      }

      await fetchAllData();
    } catch (e) {
      debugPrint('Error scheduling hearing: $e');
      rethrow;
    }
  }

  Future<void> updateHearingStatus(
    String hearingId, 
    String caseId, 
    String newStatus, 
    String remarks, {
    DateTime? newDate,
    String? newTime,
    String? newCourtroom,
  }) async {
    try {
      // 1. Update cases table
      final updateData = <String, dynamic>{
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (newDate != null) {
        updateData['next_hearing_date'] = newDate.toIso8601String();
      }
      if (remarks.isNotEmpty) {
        updateData['purpose'] = remarks;
      }
      if (newCourtroom != null && newCourtroom.isNotEmpty) {
        updateData['court_name'] = newCourtroom;
      }
      await _supabase.from('cases').update(updateData).eq('id', caseId);

      // 2. Case update timeline
      await addCaseUpdate(
        caseId, 
        'Hearing $newStatus', 
        'Hearing status updated to $newStatus by Advocate Clerk. ${newDate != null ? 'New Date: ${DateFormat('dd MMM yyyy').format(newDate.toLocal())}. ' : ''}$remarks'
      );

      // 3. Update hearings table if not synthetic
      if (!hearingId.startsWith('case_hearing_')) {
        try {
          final hearingUpdateData = <String, dynamic>{
            'status': newStatus,
            'remarks': remarks,
            'updated_at': DateTime.now().toIso8601String(),
          };
          if (newDate != null) {
            hearingUpdateData['hearing_date'] = newDate.toIso8601String();
          }
          if (newTime != null) {
            hearingUpdateData['hearing_time'] = newTime;
          }
          if (newCourtroom != null && newCourtroom.isNotEmpty) {
            hearingUpdateData['courtroom'] = newCourtroom;
          }
          await _supabase.from('hearings').update(hearingUpdateData).eq('id', hearingId);
        } catch (he) {
          debugPrint('Non-critical: hearings table update: $he');
        }
      }

      // 4. Send notifications
      final caseQuery = await _supabase.from('cases').select('user_id, lawyer_id, case_number, title').eq('id', caseId).maybeSingle();
      if (caseQuery != null) {
        final ref = caseQuery['case_number']?.isNotEmpty == true ? caseQuery['case_number'] : caseQuery['title'];
        String msg = newStatus == 'Completed' 
            ? 'The hearing for $ref has been marked as Completed.' 
            : newStatus == 'Postponed' || newStatus == 'Adjourned'
                ? 'The hearing for $ref has been adjourned/postponed. $remarks'
                : 'The hearing details for $ref have been updated to $newStatus.';

        if (caseQuery['lawyer_id'] != null) {
          await _sendNotification(caseQuery['lawyer_id'], 'Hearing $newStatus', msg, caseId);
        }
        if (caseQuery['user_id'] != null) {
          await _sendNotification(caseQuery['user_id'], 'Hearing $newStatus', msg, caseId);
        }
      }

      await fetchAllData();
    } catch (e) {
      debugPrint('Error updating hearing: $e');
      rethrow;
    }
  }

  // --- Comprehensive Case Notification Helper for Users ---
  Future<void> _notifyUserAboutCase({
    required String caseId,
    required String title,
    required String message,
  }) async {
    try {
      final caseRow = await _supabase
          .from('cases')
          .select('user_id, lawyer_id, petitioner, title, case_number')
          .eq('id', caseId)
          .maybeSingle();

      if (caseRow == null) return;

      final userId = caseRow['user_id'];
      final lawyerId = caseRow['lawyer_id'];
      final petitioner = caseRow['petitioner'];

      final targetIdentifiers = <String>{};

      if (userId != null && userId.toString().trim().isNotEmpty) {
        final uidStr = userId.toString().trim();
        targetIdentifiers.add(uidStr);
        final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(uidStr);
        if (isUuid) {
          final profileQuery = await _supabase.from('profiles').select('username, email').eq('id', uidStr).maybeSingle();
          if (profileQuery != null) {
            if (profileQuery['username'] != null) targetIdentifiers.add(profileQuery['username'].toString().trim());
            if (profileQuery['email'] != null) targetIdentifiers.add(profileQuery['email'].toString().trim());
          }
        } else {
          final profileQuery = await _supabase.from('profiles').select('id, username, email').or('username.ilike.' + uidStr + ',email.ilike.' + uidStr).maybeSingle();
          if (profileQuery != null) {
            if (profileQuery['id'] != null) targetIdentifiers.add(profileQuery['id'].toString().trim());
            if (profileQuery['username'] != null) targetIdentifiers.add(profileQuery['username'].toString().trim());
            if (profileQuery['email'] != null) targetIdentifiers.add(profileQuery['email'].toString().trim());
          }
        }
      }

      if (petitioner != null && petitioner.toString().trim().isNotEmpty) {
        final petStr = petitioner.toString().trim();
        targetIdentifiers.add(petStr);
        final petProfile = await _supabase.from('profiles').select('id, username, email').ilike('username', petStr).maybeSingle();
        if (petProfile != null) {
          if (petProfile['id'] != null) targetIdentifiers.add(petProfile['id'].toString().trim());
          if (petProfile['username'] != null) targetIdentifiers.add(petProfile['username'].toString().trim());
          if (petProfile['email'] != null) targetIdentifiers.add(petProfile['email'].toString().trim());
        }
      }

      final sentTargets = <String>{};
      for (final target in targetIdentifiers) {
        if (target.isNotEmpty && !sentTargets.contains(target.toLowerCase())) {
          sentTargets.add(target.toLowerCase());
          await _supabase.from('app_notifications').insert({
            'id': const Uuid().v4(),
            'target_user': target,
            'title': title,
            'message': message,
            'is_read': false,
            'action_payload': caseId,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      // Also notify lawyer
      if (lawyerId != null && lawyerId.toString().isNotEmpty) {
        final lidStr = lawyerId.toString().trim();
        final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(lidStr);
        String lawyerTarget = lidStr;
        if (isUuid) {
          final lawyerProfile = await _supabase.from('profiles').select('username').eq('id', lidStr).maybeSingle();
          if (lawyerProfile != null && lawyerProfile['username'] != null) {
            lawyerTarget = lawyerProfile['username'].toString().trim();
          }
        }
        if (!sentTargets.contains(lawyerTarget.toLowerCase())) {
          sentTargets.add(lawyerTarget.toLowerCase());
          await _supabase.from('app_notifications').insert({
            'id': const Uuid().v4(),
            'target_user': lawyerTarget,
            'title': title,
            'message': message,
            'is_read': false,
            'action_payload': caseId,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (e) {
      debugPrint('Error notifying user about case: $e');
    }
  }

  // --- Internal Notification Helper ---
  Future<void> _sendNotification(String userId, String title, String message, String relatedId) async {
    try {
      String targetUser = userId;
      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(userId);
      if (isUuid) {
        final profileQuery = await _supabase.from('profiles').select('username').eq('id', userId).maybeSingle();
        if (profileQuery != null && profileQuery['username'] != null) {
          targetUser = profileQuery['username'];
        }
      }

      await _supabase.from('app_notifications').insert({
        'id': const Uuid().v4(),
        'target_user': targetUser,
        'title': title,
        'message': message,
        'is_read': false,
        'action_payload': relatedId,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (targetUser != userId) {
        await _supabase.from('app_notifications').insert({
          'id': const Uuid().v4(),
          'target_user': userId,
          'title': title,
          'message': message,
          'is_read': false,
          'action_payload': relatedId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }
}

