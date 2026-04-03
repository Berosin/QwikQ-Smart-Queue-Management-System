import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/token_model.dart';
import '../models/queue_model.dart';
import '../services/queue_service.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';
import 'package:flutter/foundation.dart';

// ── Service provider ──────────────────────────────────────────
final queueServiceProvider = Provider<QueueService>((ref) => QueueService());

// ── Active tokens for current user (REAL-TIME) ────────────────
final activeTokensProvider = StreamProvider.autoDispose<List<TokenModel>>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream.value([]);

  // Use Supabase stream to watch for any changes in the user's active tokens
  return SupabaseService.client
      .from('tokens')
      .stream(primaryKey: ['id'])
      .eq('user_id', user.id)
      .map((data) {
        // Filter locally for active statuses and sort
        final activeList = data
            .map((json) => TokenModel.fromJson(json))
            .where((t) => t.isActive)
            .toList();
        
        // Sort by creation time (newest first)
        activeList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return activeList;
      });
});

// ── Token history ─────────────────────────────────────────────
final tokenHistoryProvider =
    FutureProvider.autoDispose<List<TokenModel>>((ref) async {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return [];
  return ref.read(queueServiceProvider).getUserTokenHistory(user.id);
});

// ── Single token (by id) ──────────────────────────────────────
final tokenByIdProvider =
    FutureProvider.autoDispose.family<TokenModel?, String>((ref, tokenId) async {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return null;
  
  // Directly fetch the specific token to ensure we get the latest data
  final data = await SupabaseService.client
      .from('tokens')
      .select('*, shops(name, category, queues(current_token))')
      .eq('id', tokenId)
      .maybeSingle();
      
  if (data == null) throw Exception('Token not found');
  return TokenModel.fromJson(data);
});

// ── Live queue state for a shop ───────────────────────────────
class QueueState {
  final QueueModel? queue;
  final bool isLoading;
  final String? error;

  const QueueState({this.queue, this.isLoading = false, this.error});

  QueueState copyWith({QueueModel? queue, bool? isLoading, String? error}) =>
      QueueState(
        queue: queue ?? this.queue,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
      );
}

class QueueNotifier extends StateNotifier<QueueState> {
  final String shopId;
  final QueueService _service;
  dynamic _channel;

  QueueNotifier(this.shopId, this._service) : super(const QueueState(isLoading: true)) {
    _load();
    _subscribe();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client
          .from('queues')
          .select()
          .eq('shop_id', shopId)
          .maybeSingle();
      
      if (data == null) {
        state = const QueueState(queue: null, isLoading: false);
        return;
      }
      state = QueueState(queue: QueueModel.fromJson(data));
    } catch (e) {
      state = QueueState(error: e.toString());
    }
  }

  void _subscribe() {
    _channel = _service.watchQueue(shopId, (data) {
      final updated = QueueModel.fromJson(data);
      state = state.copyWith(queue: updated, isLoading: false);
    });
  }

  Future<void> refresh() => _load();

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final liveQueueProvider =
    StateNotifierProvider.autoDispose.family<QueueNotifier, QueueState, String>(
  (ref, shopId) => QueueNotifier(shopId, ref.read(queueServiceProvider)),
);

// ── Token booking state machine ───────────────────────────────
enum BookingStep { idle, loading, success, error }

class BookingState {
  final BookingStep step;
  final TokenModel? token;
  final String? errorMessage;

  const BookingState({
    this.step = BookingStep.idle,
    this.token,
    this.errorMessage,
  });

  bool get isLoading => step == BookingStep.loading;
  bool get isSuccess => step == BookingStep.success;
  bool get hasError => step == BookingStep.error;

  const BookingState.loading() : this(step: BookingStep.loading);
  const BookingState.success(TokenModel t) : this(step: BookingStep.success, token: t);
  const BookingState.error(String msg) : this(step: BookingStep.error, errorMessage: msg);
}

class BookingNotifier extends StateNotifier<BookingState> {
  final QueueService _service;
  final String _userId;

  BookingNotifier(this._service, this._userId) : super(const BookingState());

  Future<void> bookToken({
    required String shopId,
    int groupSize = 1,
    bool isPriority = false,
    String? priorityReason,
  }) async {
    state = const BookingState.loading();
    try {
      final token = await _service.bookToken(
        shopId: shopId,
        userId: _userId,
        groupSize: groupSize,
        isPriority: isPriority,
        priorityReason: priorityReason,
      );
      state = BookingState.success(token);
    } catch (e) {
      debugPrint('BOOKING REJECTION: $e');
      state = BookingState.error(_humanError(e.toString()));
    }
  }

  Future<void> bookSlot({
    required String shopId,
    required DateTime slotStart,
    required DateTime slotEnd,
  }) async {
    state = const BookingState.loading();
    try {
      final token = await _service.bookSlot(
        shopId: shopId,
        userId: _userId,
        slotStart: slotStart,
        slotEnd: slotEnd,
      );
      state = BookingState.success(token);
    } catch (e) {
      debugPrint('SLOT BOOKING REJECTION: $e');
      state = BookingState.error(_humanError(e.toString()));
    }
  }

  void reset() => state = const BookingState();

  String _humanError(String raw) {
    if (raw.contains('already have an active token')) {
      return 'You already have an active token here.';
    }
    if (raw.contains('closed')) return 'This shop is currently closed.';
    return 'Booking failed. Please try again.';
  }
}

final bookingProvider =
    StateNotifierProvider.autoDispose.family<BookingNotifier, BookingState, String>(
  (ref, userId) => BookingNotifier(ref.watch(queueServiceProvider), userId),
);

// ── Admin queue control ───────────────────────────────────────
class AdminQueueNotifier extends StateNotifier<AsyncValue<void>> {
  final QueueService _service;
  AdminQueueNotifier(this._service) : super(const AsyncValue.data(null));

  Future<int?> callNext(String shopId) async {
    state = const AsyncValue.loading();
    try {
      final next = await _service.advanceQueue(shopId);
      state = const AsyncValue.data(null);
      return next;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> completeToken(String tokenId) async {
    await _service.completeToken(tokenId);
  }

  Future<void> skipToken(String tokenId) async {
    await _service.skipToken(tokenId);
  }

  Future<void> markPriority(String tokenId, String reason) async {
    await _service.markTokenPriority(tokenId, reason);
  }

  Future<void> pauseQueue(String shopId, {String? reason}) async {
    await _service.pauseQueue(shopId, reason: reason);
  }

  Future<void> resumeQueue(String shopId) async {
    await _service.resumeQueue(shopId);
  }
}

final adminQueueProvider =
    StateNotifierProvider<AdminQueueNotifier, AsyncValue<void>>(
  (ref) => AdminQueueNotifier(ref.watch(queueServiceProvider)),
);
