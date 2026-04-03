import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles local notifications triggered by Supabase Realtime events.
/// Call [NotificationService.initialize()] in main() after Supabase init.
class NotificationService {
  NotificationService._();

  static final _localNotifications = FlutterLocalNotificationsPlugin();

  // ── Android notification channels ────────────────────────────
  static const _queueChannel = AndroidNotificationChannel(
    'queue_updates',
    'Queue Updates',
    description: 'Token status and queue progress notifications',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    ledColor: Color(0xFF007BFF),
  );

  static const _turnChannel = AndroidNotificationChannel(
    'your_turn',
    'Your Turn',
    description: 'Alerts when it is your turn',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    ledColor: Color(0xFF00E676),
  );

  // ── Initialize ───────────────────────────────────────────────
  static Future<void> initialize() async {
    // 1. Create Android channels
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_queueChannel);
    await androidPlugin?.createNotificationChannel(_turnChannel);

    // 2. Initialize local notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
  }

  // ── Show local notification ──────────────────────────────────
  static Future<void> show({
    required int id,
    required String title,
    required String body,
    String channelId = 'queue_updates',
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == 'your_turn' ? 'Your Turn' : 'Queue Updates',
      importance: channelId == 'your_turn' ? Importance.max : Importance.high,
      priority: Priority.high,
      color: const Color(0xFF007BFF),
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  // ── Queue-specific notifications ─────────────────────────────

  /// Show "3 people ahead" alert
  static Future<void> notifyNearTurn({
    required int tokenNumber,
    required String shopName,
    required int peopleAhead,
  }) async {
    await show(
      id: tokenNumber,
      title: '⏳ Almost Your Turn at $shopName',
      body: '$peopleAhead more ${peopleAhead == 1 ? 'person' : 'people'} ahead. Start heading over now!',
      channelId: 'queue_updates',
      payload: 'near_turn:$tokenNumber',
    );
  }

  /// Show "It's your turn!" alert
  static Future<void> notifyYourTurn({
    required int tokenNumber,
    required String shopName,
  }) async {
    await show(
      id: tokenNumber + 10000,
      title: '🔔 Token #$tokenNumber — IT\'S YOUR TURN!',
      body: 'Please proceed to the counter at $shopName now.',
      channelId: 'your_turn',
      payload: 'your_turn:$tokenNumber',
    );
  }

  /// Show token expired / skipped alert
  static Future<void> notifyTokenExpired({
    required int tokenNumber,
    required String shopName,
  }) async {
    await show(
      id: tokenNumber + 20000,
      title: '❌ Token #$tokenNumber Expired',
      body: 'Your token at $shopName was skipped. Book a new one to rejoin.',
      channelId: 'queue_updates',
    );
  }

  // ── DB Notifications (Supabase) ──────────────────────────────

  static Future<List<Map<String, dynamic>>> getUserNotifications(
      String userId) async {
    final data = await SupabaseService.client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('sent_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(data as List);
  }

  static Future<int> getUnreadCount(String userId) async {
    final result = await SupabaseService.client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .eq('is_read', false)
        .count(CountOption.exact);
    return result.count ?? 0;
  }

  static Future<void> markAllRead(String userId) async {
    await SupabaseService.client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  static Future<void> markRead(String notificationId) async {
    await SupabaseService.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  static Future<void> createDbNotification({
    required String userId,
    required String tokenId,
    required String shopId,
    required String title,
    required String body,
    required String type,
  }) async {
    await SupabaseService.client.from('notifications').insert({
      'user_id': userId,
      'token_id': tokenId,
      'shop_id': shopId,
      'title': title,
      'body': body,
      'type': type,
    });
  }

  /// Subscribe to real-time notifications for user
  static RealtimeChannel watchNotifications(
    String userId,
    void Function(Map<String, dynamic>) onNew,
  ) {
    return SupabaseService.client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            // Also trigger a local notification when a new DB record arrives
            show(
              id: record['id'].hashCode,
              title: record['title'] ?? 'QwikQ Update',
              body: record['body'] ?? '',
              payload: record['type'],
            );
            onNew(record);
          },
        )
        .subscribe();
  }

  // ── Cancel notifications ─────────────────────────────────────
  static Future<void> cancel(int id) async {
    await _localNotifications.cancel(id);
  }

  static Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }

  // ── Private handlers ─────────────────────────────────────────
  static void _onLocalNotificationTap(NotificationResponse response) {
    // Navigate based on payload — implement using GoRouter or NavigatorKey
    debugPrint('Notification tapped: ${response.payload}');
  }
}
