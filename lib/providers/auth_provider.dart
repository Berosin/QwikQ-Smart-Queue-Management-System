import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart' as global_service;
import '../services/notification_service.dart';

// ============================================================
// auth_provider.dart
// ============================================================
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<dynamic>((ref) {
  return ref.watch(authServiceProvider).authStateStream;
});

// Stream provider for real-time user profile
final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final auth = ref.watch(authServiceProvider);
  if (!auth.isLoggedIn) return Stream.value(null);

  final userId = auth.currentUser!.id;

  // Start watching notifications for this user
  final channel = NotificationService.watchNotifications(userId, (newNotif) {
    // Local notification is triggered inside watchNotifications callback
  });

  ref.onDispose(() => channel.unsubscribe());

  // Use Supabase .stream() to watch the users table for point changes
  // This requires: ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
  return global_service.SupabaseService.client
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((data) {
        if (data.isEmpty) return null;
        return UserModel.fromJson(data.first);
      });
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final auth = ref.watch(authServiceProvider);
  if (!auth.isLoggedIn) return null;
  return auth.getUserProfile(auth.currentUser!.id);
});
