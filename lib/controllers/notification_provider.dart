import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification.dart';

class NotificationProvider with ChangeNotifier {
  List<AppNotification> _notifications = [];
  final _supabase = Supabase.instance.client;

  bool _isListening = false;
  String? _currentTargetUser;

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
          // Optional: we can add a filter here, but we will always fetch again
          callback: (payload) {
            // Because targetUser is captured in this closure, we must ensure it matches
            // the currently active user, though since we remove the old channel, this
            // closure should only fire for the correct channel.
            if (_currentTargetUser == targetUser) {
              fetchNotifications(targetUser);
            }
          },
        )
        .subscribe();
  }

  Future<void> fetchNotifications(String targetUser) async {
    _setupRealtime(targetUser);
    try {
      final response = await _supabase
          .from('app_notifications')
          .select()
          .eq('target_user', targetUser)
          .order('created_at', ascending: false);

      _notifications = response.map<AppNotification>((row) => AppNotification(
        id: row['id'],
        title: row['title'],
        message: row['message'],
        isRead: row['is_read'],
        timestamp: DateTime.parse(row['created_at']),
        actionPayload: row['action_payload'],
      )).toList();
      
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
      });
      // Optionally fetch again, but since this is usually sent TO someone else, 
      // the sender doesn't need to re-fetch their own notifications
    } catch (e) {
      debugPrint('Error adding notification: $e');
    }
  }

  Future<void> markAllAsRead(String targetUser) async {
    try {
      for (var n in _notifications) {
        n.isRead = true;
      }
      notifyListeners(); // Optimistic update
      
      await _supabase
          .from('app_notifications')
          .update({'is_read': true})
          .eq('target_user', targetUser)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }
}
