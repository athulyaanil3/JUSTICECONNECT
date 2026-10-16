import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/encryption_service.dart';
import '../models/consultation_request.dart';
import 'package:uuid/uuid.dart';

class RequestProvider with ChangeNotifier {
  List<ConsultationRequest> _requests = [];
  final _supabase = Supabase.instance.client;
  bool _isListening = false;
  String? _currentUsername;
  String? _currentRole;
  
  String? get currentUsername => _currentUsername;
  String? get currentRole => _currentRole;

  RequestProvider() {
    _setupRealtime();
    _setupAuthListener();
    if (_supabase.auth.currentUser != null) {
      fetchRequests();
    }
  }

  void _setupAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.userUpdated) {
        fetchRequests();
      } else if (event == AuthChangeEvent.signedOut) {
        clear();
      }
    });
  }

  void clear() {
    _requests = [];
    _currentUsername = null;
    _currentRole = null;
    notifyListeners();
  }

  void _setupRealtime() {
    if (_isListening) return;
    _isListening = true;
    
    // Listen to real-time chat messages
    _supabase
        .channel('public:chat_messages_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            fetchRequests();
          },
        )
        .subscribe();

    // Also listen to consultation request updates
    _supabase
        .channel('public:consultation_requests_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'consultation_requests',
          callback: (payload) {
            fetchRequests();
          },
        )
        .subscribe();
  }

  List<ConsultationRequest> get requests => _requests;

  // Initialize and listen to database changes
  Future<void> fetchRequests() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _requests = [];
        notifyListeners();
        return;
      }

      // Fetch profile with error tolerance
      Map<String, dynamic>? profile;
      try {
        profile = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
      } catch (e) {
        debugPrint('Non-critical: error fetching profile in RequestProvider: $e');
      }

      final profileUsername = (profile?['username'] ?? '').toString().trim();
      final metaUsername = (user.userMetadata?['username'] ?? '').toString().trim();
      final email = (user.email ?? '').trim();
      final emailPrefix = email.contains('@') ? email.split('@')[0].trim() : '';

      _currentRole = profile?['role'] ?? user.userMetadata?['role'] ?? 'Citizen';
      _currentUsername = profileUsername.isNotEmpty 
          ? profileUsername 
          : (metaUsername.isNotEmpty ? metaUsername : (emailPrefix.isNotEmpty ? emailPrefix : 'User'));

      // Build collection of all possible usernames/identifiers for this account
      final Set<String> candidates = {};
      if (profileUsername.isNotEmpty) candidates.add(profileUsername);
      if (metaUsername.isNotEmpty) candidates.add(metaUsername);
      if (email.isNotEmpty) candidates.add(email);
      if (emailPrefix.isNotEmpty) candidates.add(emailPrefix);

      if (candidates.isEmpty) {
        _requests = [];
        notifyListeners();
        return;
      }

      var query = _supabase.from('consultation_requests').select();

      if (_currentRole == 'Citizen') {
        final orFilters = candidates.map((c) => 'citizen_name.ilike.$c').join(',');
        query = query.or(orFilters);
      } else if (_currentRole == 'Lawyer') {
        final orFilters = candidates.map((c) => 'lawyer_name.ilike.$c').join(',');
        query = query.or(orFilters);
      } else if (_currentRole != 'Admin') {
        // Advocate Clerk or other roles
        _requests = [];
        notifyListeners();
        return;
      }

      final response = await query.order('requested_at', ascending: false);

      final List<ConsultationRequest> loadedRequests = [];
      
      for (var row in response) {
        // Fetch messages for this request
        final messagesResponse = await _supabase
            .from('chat_messages')
            .select()
            .eq('request_id', row['id'])
            .order('created_at', ascending: true);
            
        List<Map<String, dynamic>> messages = [];
        for (var msgRow in messagesResponse) {
          DateTime? msgTime;
          if (msgRow['created_at'] != null) {
            msgTime = DateTime.tryParse(msgRow['created_at'].toString())?.toLocal();
          }
          final formattedTime = msgTime != null 
              ? DateFormat('hh:mm a').format(msgTime) 
              : '';

          String decryptedText = '';
          try {
            decryptedText = EncryptionService.decryptText(msgRow['text'] ?? '');
          } catch (_) {
            decryptedText = (msgRow['text'] ?? '').toString();
          }

          messages.add({
            'text': decryptedText,
            'sender': msgRow['sender'] ?? '',
            'time': formattedTime,
          });
        }

        DateTime requestedAt;
        try {
          requestedAt = DateTime.parse(row['requested_at'].toString()).toLocal();
        } catch (_) {
          requestedAt = DateTime.now();
        }

        loadedRequests.add(ConsultationRequest(
          id: row['id'],
          citizenName: row['citizen_name'] ?? 'Citizen',
          lawyerName: row['lawyer_name'] ?? 'Lawyer',
          issueDescription: row['issue_description'] ?? '',
          status: row['status'] ?? 'Pending',
          requestedAt: requestedAt,
          messages: messages,
        ));
      }
      
      _requests = loadedRequests;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching requests: $e');
    }
  }

  Future<void> addRequest(ConsultationRequest request) async {
    // Enforce correct citizenName from current identity
    final effectiveCitizenName = (_currentUsername != null && _currentUsername!.isNotEmpty)
        ? _currentUsername!
        : request.citizenName;

    request = ConsultationRequest(
      id: request.id,
      citizenName: effectiveCitizenName,
      lawyerName: request.lawyerName,
      issueDescription: request.issueDescription,
      requestedAt: request.requestedAt,
      status: request.status,
      messages: request.messages,
    );

    // Optimistic update
    _requests.insert(0, request);
    notifyListeners();

    try {
      await _supabase.from('consultation_requests').insert({
        'id': request.id,
        'citizen_name': request.citizenName,
        'lawyer_name': request.lawyerName,
        'issue_description': request.issueDescription,
        'status': request.status,
        'requested_at': request.requestedAt.toIso8601String(),
      });
      
      // Send notification to lawyer
      await _supabase.from('app_notifications').insert({
        'id': Uuid().v4(),
        'target_user': request.lawyerName,
        'title': 'New Consultation Request',
        'message': '${request.citizenName} has requested a consultation regarding: ${request.issueDescription}',
        'is_read': false,
        'action_payload': request.id,
      });

      // Send notification to citizen
      await _supabase.from('app_notifications').insert({
        'id': Uuid().v4(),
        'target_user': request.citizenName,
        'title': 'Request Sent',
        'message': 'You have sent a consultation request to ${request.lawyerName}.',
        'is_read': false,
        'action_payload': request.id,
      });

      await fetchRequests(); // Refresh list
    } catch (e) {
      debugPrint('Error adding request: $e');
      _requests.removeWhere((r) => r.id == request.id);
      notifyListeners();
    }
  }

  Future<void> lawyerProceedsRequest(String id, String citizenName) async {
    // Optimistic Update
    final index = _requests.indexWhere((r) => r.id == id);
    if (index != -1) {
      _requests[index].status = 'Awaiting Confirmation';
      notifyListeners();
    }

    try {
      await _supabase
          .from('consultation_requests')
          .update({'status': 'Awaiting Confirmation'})
          .eq('id', id);

      // Send notification to citizen
      await _supabase.from('app_notifications').insert({
        'id': Uuid().v4(),
        'target_user': citizenName,
        'title': 'Lawyer Proceeded',
        'message': 'Your lawyer has proceeded with your consultation request. Please confirm to begin consultations.',
        'is_read': false,
        'action_payload': id,
      });

      await fetchRequests();
    } catch (e) {
      debugPrint('Error proceeding request: $e');
    }
  }

  Future<void> userConfirmsLawyer(String id, String lawyerName) async {
    // Optimistic Update
    final index = _requests.indexWhere((r) => r.id == id);
    if (index != -1) {
      _requests[index].status = 'Accepted';
      notifyListeners();
    }

    try {
      await _supabase
          .from('consultation_requests')
          .update({'status': 'Accepted'})
          .eq('id', id);

      // Send notification to lawyer
      await _supabase.from('app_notifications').insert({
        'id': Uuid().v4(),
        'target_user': lawyerName,
        'title': 'User Confirmed',
        'message': 'The citizen has confirmed the consultation. You can now chat with them.',
        'is_read': false,
        'action_payload': id,
      });

      await fetchRequests();
    } catch (e) {
      debugPrint('Error confirming request: $e');
    }
  }

  Future<void> updateRequestStatus(String id, String newStatus) async {
    final index = _requests.indexWhere((r) => r.id == id);
    if (index != -1) {
      _requests[index].status = newStatus;
      notifyListeners();
    }

    try {
      await _supabase
          .from('consultation_requests')
          .update({'status': newStatus})
          .eq('id', id);

      // Notify the other party about status change
      if (index != -1) {
        final req = _requests[index];
        final targetUser = _currentRole == 'Lawyer' ? req.citizenName : req.lawyerName;
        final senderName = _currentRole == 'Lawyer' ? req.lawyerName : req.citizenName;
        
        await _supabase.from('app_notifications').insert({
          'id': Uuid().v4(),
          'target_user': targetUser,
          'title': 'Consultation Status Updated',
          'message': '$senderName has updated the consultation status to "$newStatus".',
          'is_read': false,
          'action_payload': req.id,
        });
      }

      await fetchRequests();
    } catch (e) {
      debugPrint('Error updating request status: $e');
    }
  }

  Future<void> addMessageToRequest(String id, Map<String, dynamic> message) async {
    // Optimistic Update
    final index = _requests.indexWhere((r) => r.id == id);
    if (index != -1) {
      _requests[index].messages.add(message);
      notifyListeners();
    }

    try {
      await _supabase.from('chat_messages').insert({
        'request_id': id,
        'sender': message['sender'],
        'text': EncryptionService.encryptText(message['text'] ?? ''),
      });
      await fetchRequests(); // Refresh list to get accurate timestamps from DB
    } catch (e) {
      debugPrint('Error adding message: $e');
      if (index != -1) {
        _requests[index].messages.removeLast();
        notifyListeners();
      }
    }
  }
}
