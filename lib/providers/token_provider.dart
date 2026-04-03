import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/token_model.dart';
import '../services/queue_service.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';
import 'queue_provider.dart';

// ── Live token tracker ────────────────────────────────────────
/// Watches a single token in real-time via Supabase Realtime.
class LiveTokenNotifier extends StateNotifier<AsyncValue<TokenModel?>> {
  final String tokenId;
  final QueueService _service;
  dynamic _tokenChannel;
  dynamic _queueChannel;

  LiveTokenNotifier(this.tokenId, this._service)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client
          .from('tokens')
          .select('*, shops(name, category, queues(current_token, total_waiting, avg_service_time))')
          .eq('id', tokenId)
          .single();

      final token = TokenModel.fromJson(data);
      state = AsyncValue.data(token);

      // Subscribe to this token's updates
      _tokenChannel = _service.watchToken(tokenId, (updated) {
        state = AsyncValue.data(updated);
      });

      // Subscribe to queue updates for estimated wait refresh
      _queueChannel = _service.watchQueue(token.shopId, (queueData) {
        final current = state.valueOrNull;
        if (current == null) return;
        // Rebuild token with refreshed queue position
        final newCurrentToken = queueData['current_token'] as int? ?? 0;
        final avgTime = (queueData['avg_service_time'] as num?)?.toDouble() ?? 5.0;
        final position = (current.tokenNumber - newCurrentToken).clamp(0, 999);
        final newWait = (position * avgTime).round();
        state = AsyncValue.data(_rebuildToken(current, newCurrentToken, newWait));
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  TokenModel _rebuildToken(TokenModel t, int currentQ, int wait) =>
      TokenModel(
        id: t.id,
        tokenNumber: t.tokenNumber,
        shopId: t.shopId,
        userId: t.userId,
        groupSize: t.groupSize,
        status: t.status,
        isPriority: t.isPriority,
        priorityReason: t.priorityReason,
        bookingType: t.bookingType,
        estimatedWaitMinutes: wait,
        aiPredictedWait: t.aiPredictedWait,
        qrCode: t.qrCode,
        arrivedAt: t.arrivedAt,
        servedAt: t.servedAt,
        completedAt: t.completedAt,
        cancelledAt: t.cancelledAt,
        expiryTime: t.expiryTime,
        createdAt: t.createdAt,
        shopName: t.shopName,
        shopCategory: t.shopCategory,
        currentQueueToken: currentQ,
      );

  Future<void> refresh() => _load();

  @override
  void dispose() {
    _tokenChannel?.unsubscribe();
    _queueChannel?.unsubscribe();
    super.dispose();
  }
}

final liveTokenProvider = StateNotifierProvider.autoDispose
    .family<LiveTokenNotifier, AsyncValue<TokenModel?>, String>(
  (ref, tokenId) =>
      LiveTokenNotifier(tokenId, ref.read(queueServiceProvider)),
);

// ── Token history with pagination ─────────────────────────────
class TokenHistoryNotifier extends StateNotifier<AsyncValue<List<TokenModel>>> {
  final String userId;
  final QueueService _service;
  int _page = 0;
  bool _hasMore = true;

  TokenHistoryNotifier(this.userId, this._service)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final tokens = await _service.getUserTokenHistory(userId, page: _page);
      final prev = state.valueOrNull ?? [];
      state = AsyncValue.data([...prev, ...tokens]);
      if (tokens.length < 20) _hasMore = false;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    _page++;
    await _load();
  }

  Future<void> refresh() async {
    _page = 0;
    _hasMore = true;
    state = const AsyncValue.loading();
    await _load();
  }

  bool get hasMore => _hasMore;
}

final tokenHistoryNotifierProvider = StateNotifierProvider.autoDispose
    .family<TokenHistoryNotifier, AsyncValue<List<TokenModel>>, String>(
  (ref, userId) =>
      TokenHistoryNotifier(userId, ref.read(queueServiceProvider)),
);

// ── Unread notification count ─────────────────────────────────
final unreadNotificationCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) {
    yield 0;
    return;
  }

  // Initial fetch using FetchOptions
  final response = await SupabaseService.client
    .from('notifications')
    .select()
    .eq('user_id', user.id)
    .eq('is_read', false);
  yield (response as List).length;

  // Real-time updates — use .stream() directly on .from(), not on .channel()
  yield* SupabaseService.client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', user.id)
      .map((rows) => rows.where((r) => r['is_read'] == false).length);
});
// ── Token statistics for profile ──────────────────────────────
class TokenStats {
  final int total;
  final int completed;
  final int cancelled;
  final double avgWaitMinutes;
  final double onTimeRate;

  const TokenStats({
    this.total = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.avgWaitMinutes = 0,
    this.onTimeRate = 0,
  });
}

final tokenStatsProvider = FutureProvider.autoDispose.family<TokenStats, String>(
  (ref, userId) async {
    final data = await SupabaseService.client
        .from('tokens')
        .select('status, actual_wait_minutes, arrived_at, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100);

    final rows = data as List;
    final total = rows.length;
    final completed = rows.where((r) => r['status'] == 'completed').length;
    final cancelled = rows.where((r) => r['status'] == 'cancelled').length;

    final waits = rows
        .where((r) => r['actual_wait_minutes'] != null)
        .map((r) => (r['actual_wait_minutes'] as num).toDouble())
        .toList();
    final avgWait = waits.isEmpty
        ? 0.0
        : waits.reduce((a, b) => a + b) / waits.length;

    return TokenStats(
      total: total,
      completed: completed,
      cancelled: cancelled,
      avgWaitMinutes: avgWait,
      onTimeRate: total == 0 ? 0 : completed / total,
    );
  },
);