import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/encryption_service.dart';

class FilingChatProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String? _currentFilingId;
  RealtimeChannel? _subscription;

  List<Map<String, dynamic>> get messages => _messages;
  bool get isLoading => _isLoading;

  Future<void> loadChatForFiling(String filingId) async {
    _currentFilingId = filingId;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('filing_messages')
          .select()
          .eq('filing_id', filingId)
          .order('created_at', ascending: true);

      final List<Map<String, dynamic>> decryptedMessages = [];
      for (var msg in response) {
        final newMsg = Map<String, dynamic>.from(msg);
        newMsg['text'] = EncryptionService.decryptText(newMsg['text'] ?? '');
        decryptedMessages.add(newMsg);
      }
      
      _messages = decryptedMessages;
      _setupRealtime(filingId);
    } catch (e) {
      debugPrint('Error loading filing chat: ');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setupRealtime(String filingId) {
    _subscription?.unsubscribe();
    _subscription = _supabase
        .channel('public:filing_messages:filing_id=eq.')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'filing_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'filing_id',
            value: filingId,
          ),
          callback: (payload) {
            final newMessage = Map<String, dynamic>.from(payload.newRecord);
            newMessage['text'] = EncryptionService.decryptText(newMessage['text'] ?? '');
            
            // Prevent duplicate insertion if the current user just sent it
            if (!_messages.any((m) => m['id'] == newMessage['id'])) {
              _messages.add(newMessage);
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  Future<void> sendMessage(String text, String senderRole) async {
    if (_currentFilingId == null || text.trim().isEmpty) return;

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final plainText = text.trim();
      final encryptedText = EncryptionService.encryptText(plainText);

      final newMessage = {
        'filing_id': _currentFilingId,
        'sender_role': senderRole,
        'sender_id': user.id,
        'text': encryptedText,
      };

      // Optimistically add the message to the UI
      final tempMessage = {
        ...newMessage,
        'text': plainText, // Display unencrypted text locally immediately
        'id': 'temp_',
        'created_at': DateTime.now().toIso8601String(),
      };
      
      _messages.add(tempMessage);
      notifyListeners();

      final response = await _supabase
          .from('filing_messages')
          .insert(newMessage)
          .select()
          .single();

      // Replace temp message with actual response
      final index = _messages.indexWhere((m) => m['id'] == tempMessage['id']);
      if (index != -1) {
        final decryptedResponse = Map<String, dynamic>.from(response);
        decryptedResponse['text'] = EncryptionService.decryptText(decryptedResponse['text'] ?? '');
        _messages[index] = decryptedResponse;
        notifyListeners();
      }

    } catch (e) {
      debugPrint('Error sending filing message: ');
      // Optionally remove temp message on failure
    }
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}
