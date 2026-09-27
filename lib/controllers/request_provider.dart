import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  }

  void _setupRealtime() {
    if (_isListening) return;
    _isListening = true;
    
    _supabase
        .channel('public:chat_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            fetchRequests(); // Automatically fetch new messages
          },
        )
        .subscribe();
  }

  List<ConsultationRequest> get requests => _requests;

  // Initialize and listen to database changes
  Future<void> fetchRequests() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase.from('profiles').select('username, role').eq('id', user.id).maybeSingle();
      if (profile == null) return;

      _currentUsername = profile['username'];
      _currentRole = profile['role'];

      var query = _supabase.from('consultation_requests').select();

      if (_currentRole == 'Citizen') {
        query = query.eq('citizen_name', _currentUsername ?? '');
      } else if (_currentRole == 'Lawyer') {
        query = query.eq('lawyer_name', _currentUsername ?? '');
      }
      // If admin, they see all (or you can restrict it)

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
          messages.add({
            'text': msgRow['text'],
            'sender': msgRow['sender'],
            'time': msgRow['created_at'].toString().substring(11, 16), // simple time parsing
          });
        }

        loadedRequests.add(ConsultationRequest(
          id: row['id'],
          citizenName: row['citizen_name'],
          lawyerName: row['lawyer_name'],
          issueDescription: row['issue_description'],
          status: row['status'],
          requestedAt: DateTime.parse(row['requested_at']),
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
    // Enforce correct citizenName from the database to prevent metadata mismatches
    if (_currentRole == 'Citizen' && _currentUsername != null) {
      request = ConsultationRequest(
        id: request.id,
        citizenName: _currentUsername!,
        lawyerName: request.lawyerName,
        issueDescription: request.issueDescription,
        requestedAt: request.requestedAt,
        status: request.status,
        messages: request.messages,
      );
    }

    // Optimistic update to prevent double submissions instantly
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
      
      // Send notification
      await _supabase.from('app_notifications').insert({
        'id': Uuid().v4(),
        'target_user': request.lawyerName,
        'title': 'New Consultation Request',
        'message': '${request.citizenName} has requested a consultation regarding: ${request.issueDescription}',
        'is_read': false,
        'action_payload': request.id,
      });

      await fetchRequests(); // Refresh list
    } catch (e) {
      debugPrint('Error adding request: $e');
      // Revert optimistic update on failure
      _requests.removeWhere((r) => r.id == request.id);
      notifyListeners();
    }
  }

  Future<void> lawyerProceedsRequest(String id, String citizenName) async {
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

      // Send notification
      await _supabase.from('app_notifications').insert({
        'id': Uuid().v4(),
        'target_user': citizenName,
        'title': 'Request Accepted',
        'message': 'Your lawyer has accepted your request. You can now start communicating through chat.',
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
      _requests[index].status = 'Confirmed';
      notifyListeners();
    }

    try {
      await _supabase
          .from('consultation_requests')
          .update({'status': 'Confirmed'})
          .eq('id', id);

      // Send notification
      await _supabase.from('app_notifications').insert({
        'id': Uuid().v4(),
        'target_user': lawyerName,
        'title': 'User Confirmed',
        'message': 'The user has confirmed the consultation. You can now chat with them.',
        'is_read': false,
        'action_payload': id,
      });

      await fetchRequests();
    } catch (e) {
      debugPrint('Error confirming request: $e');
    }
  }

  Future<void> updateRequestStatus(String id, String newStatus) async {
    // Optimistic Update
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
      await fetchRequests(); // Refresh list
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
        'text': message['text'],
      });
      await fetchRequests(); // Refresh list to get accurate timestamps from DB
    } catch (e) {
      debugPrint('Error adding message: $e');
      // Revert optimistic update on failure
      if (index != -1) {
        _requests[index].messages.removeLast();
        notifyListeners();
      }
    }
  }
}
