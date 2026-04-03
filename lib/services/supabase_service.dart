import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import 'dart:typed_data'; // add this

/// Central Supabase client accessor.
/// Call [SupabaseService.initialize()] once in main() before runApp.
class SupabaseService {
  SupabaseService._();

  /// The singleton Supabase client.
  static SupabaseClient get client => Supabase.instance.client;

  /// Convenience: currently signed-in user (null if not logged in).
  static User? get currentUser => client.auth.currentUser;

  /// True if a user is authenticated.
  static bool get isAuthenticated => currentUser != null;

  /// Initialize Supabase. Must be awaited before calling [client].
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
        eventsPerSecond: 10,
      ),
      storageOptions: const StorageClientOptions(
        retryAttempts: 3,
      ),
    );
  }

  // ── Realtime helpers ─────────────────────────────────────────

  /// Create and subscribe to a Postgres change channel.
  static RealtimeChannel subscribeToTable({
    required String channelName,
    required String table,
    required String schema,
    PostgresChangeEvent event = PostgresChangeEvent.all,
    PostgresChangeFilter? filter,
    required void Function(PostgresChangePayload) callback,
  }) {
    return client
        .channel(channelName)
        .onPostgresChanges(
          event: event,
          schema: schema,
          table: table,
          filter: filter,
          callback: callback,
        )
        .subscribe();
  }

  /// Unsubscribe and remove a channel safely.
  static Future<void> unsubscribe(RealtimeChannel channel) async {
    await client.removeChannel(channel);
  }

  // ── Storage helpers ──────────────────────────────────────────

  static Future<String> uploadFile({
    required String bucket,
    required String path,
    required Uint8List bytes,          // ← change List<int> to Uint8List
  String contentType = 'image/jpeg',
}) async {
  await client.storage.from(bucket).uploadBinary(
        path,
        bytes,                       // ← now correct type
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );
  return client.storage.from(bucket).getPublicUrl(path);
}

  /// Delete a file from storage.
  static Future<void> deleteFile({
    required String bucket,
    required String path,
  }) async {
    await client.storage.from(bucket).remove([path]);
  }

  // ── RPC helper ───────────────────────────────────────────────

  /// Call a Postgres RPC function with named params.
  static Future<dynamic> rpc(
    String function, {
    Map<String, dynamic>? params,
  }) async {
    return client.rpc(function, params: params);
  }
}