import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification.dart';

class NotificationProvider with ChangeNotifier {
  List<AppNotification> _notifications = [];
  final _supabase = Supabase.instance.client;

  bool _isListening = false;
  String? _currentTargetUser;
  String? _currentUserId;
  String? _currentUserEmail;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  String? get currentTargetUser => _currentTargetUser;

  RealtimeChannel? _channel;

  void _setupRealtime(String targetUser) {
    if (_isListening && _currentTargetUser == targetUser) return;
    
    // If we're already listening to another user's notifications, unsubscribe first
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
    }

    _isListening = true;
    _currentTargetUser = targetUser;
    
    _channel = _supabase
        .channel('public:app_notifications_$targetUser')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_notifications',
          callback: (payload) {
            fetchNotifications(
              _currentTargetUser ?? targetUser,
              userId: _currentUserId,
              email: _currentUserEmail,
            );
          },
        )
        .subscribe();
  }

  Future<void> fetchNotifications(String targetUser, {String? userId, String? email}) async {
    _currentUserId = userId ?? _supabase.auth.currentUser?.id;
    _currentUserEmail = email ?? _supabase.auth.currentUser?.email;
    _setupRealtime(targetUser);

    try {
      final targets = <String>{targetUser.trim()};
      if (_currentUserId != null && _currentUserId!.trim().isNotEmpty) {
        targets.add(_currentUserId!.trim());
      }
      if (_currentUserEmail != null && _currentUserEmail!.trim().isNotEmpty) {
        targets.add(_currentUserEmail!.trim());
      }

      final orFilter = targets.map((t) => 'target_user.eq.$t').join(',');

      final response = await _supabase
          .from('app_notifications')
          .select()
          .or(orFilter)
          .order('created_at', ascending: false);

      final seenIds = <String>{};
      final uniqueNotifications = <AppNotification>[];

      for (var row in response) {
        final id = row['id']?.toString() ?? '';
        if (id.isNotEmpty && !seenIds.contains(id)) {
          seenIds.add(id);
          uniqueNotifications.add(AppNotification(
            id: id,
            title: row['title'] ?? '',
            message: row['message'] ?? '',
            isRead: row['is_read'] ?? false,
            timestamp: DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
            actionPayload: row['action_payload'],
          ));
        }
      }

      _notifications = uniqueNotifications;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
  }

  Future<void> addNotification(AppNotification notification, String targetUser) async {
    try {
      await _supabase.from('app_notifications').insert({
        'id': notification.id,
        'target_user': targetUser,
        'title': notification.title,
        'message': notification.message,
        'is_read': notification.isRead,
        'action_payload': notification.actionPayload,
        'created_at': notification.timestamp.toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error adding notification: $e');
    }
  }

  Future<void> markAllAsRead(String targetUser, {String? userId, String? email}) async {
    try {
      for (var n in _notifications) {
        n.isRead = true;
      }
      notifyListeners(); // Optimistic update
      
      final effectiveUserId = userId ?? _currentUserId ?? _supabase.auth.currentUser?.id;
      final effectiveEmail = email ?? _currentUserEmail ?? _supabase.auth.currentUser?.email;

      final targets = <String>{targetUser.trim()};
      if (effectiveUserId != null && effectiveUserId.trim().isNotEmpty) targets.add(effectiveUserId.trim());
      if (effectiveEmail != null && effectiveEmail.trim().isNotEmpty) targets.add(effectiveEmail.trim());

      final orFilter = targets.map((t) => 'target_user.eq.$t').join(',');

      await _supabase
          .from('app_notifications')
          .update({'is_read': true})
          .or(orFilter)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index].isRead = true;
        notifyListeners();
      }
      await _supabase
          .from('app_notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('Error marking single notification as read: $e');
    }
  }
}
