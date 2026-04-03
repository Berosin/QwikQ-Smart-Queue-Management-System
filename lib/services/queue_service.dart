import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/token_model.dart';
import 'supabase_service.dart';

class QueueService {
  final _client = SupabaseService.client;

  // ── Book a Token ──────────────────────────────────────────────
  Future<TokenModel> bookToken({
    required String shopId,
    required String userId,
    int groupSize = 1,
    bool isPriority = false,
    String? priorityReason,
  }) async {
    try {
      // 1. Ensure queue entry exists for this shop (prevent RPC failure)
      final queueExists = await _client
          .from('queues')
          .select()
          .eq('shop_id', shopId)
          .maybeSingle();
      
      if (queueExists == null) {
        // Create missing queue entry
        await _client.from('queues').insert({'shop_id': shopId});
      }

      // 2. Check user token limit
      final existingTokens = await _client
          .from('tokens')
          .select()
          .eq('shop_id', shopId)
          .eq('user_id', userId)
          .inFilter('status', ['waiting', 'called', 'serving'])
          .count(CountOption.exact);

      if ((existingTokens.count ?? 0) >= 3) {
        throw Exception('You already have an active token at this shop');
      }

      // 3. Get next token number via RPC (This also increments last_token_number and total_waiting in DB)
      final tokenNumberResult = await _client.rpc(
        'get_next_token_number',
        params: {'p_shop_id': shopId},
      );
      final tokenNumber = int.parse(tokenNumberResult.toString());

      // 4. Get current queue state for estimated wait
      final queueData = await _client
          .from('queues')
          .select()
          .eq('shop_id', shopId)
          .single();

      final avgTime = (queueData['avg_service_time'] as num?)?.toDouble() ?? 5.0;
      final currentToken = queueData['current_token'] as int? ?? 0;
      final position = (tokenNumber - currentToken).clamp(0, 999);
      final estimatedWait = (position * avgTime).round();

      // 5. Create token record
      final expiryTime = DateTime.now().add(const Duration(hours: 2)); // Increased expiry
      final tokenData = await _client
          .from('tokens')
          .insert({
            'token_number': tokenNumber,
            'shop_id': shopId,
            'user_id': userId,
            'group_size': groupSize,
            'status': 'waiting',
            'is_priority': isPriority,
            'priority_reason': priorityReason,
            'estimated_wait_minutes': estimatedWait,
            'expiry_time': expiryTime.toIso8601String(),
            'booking_type': 'token',
          })
          .select()
          .single();

      return TokenModel.fromJson(tokenData);
    } catch (e) {
      print('BOOKING ERROR: $e');
      rethrow;
    }
  }

  // ── Book a Time Slot ──────────────────────────────────────────
  Future<TokenModel> bookSlot({
    required String shopId,
    required String userId,
    required DateTime slotStart,
    required DateTime slotEnd,
  }) async {
    final tokenNumberResult = await _client.rpc(
      'get_next_token_number',
      params: {'p_shop_id': shopId},
    );

    final tokenData = await _client
        .from('tokens')
        .insert({
          'token_number': int.parse(tokenNumberResult.toString()),
          'shop_id': shopId,
          'user_id': userId,
          'status': 'waiting',
          'booking_type': 'slot',
          'slot_start_time': slotStart.toIso8601String(),
          'slot_end_time': slotEnd.toIso8601String(),
        })
        .select()
        .single();

    return TokenModel.fromJson(tokenData);
  }

  // ── Cancel Token ──────────────────────────────────────────────
  Future<void> cancelToken(String tokenId) async {
    final token = await _client
        .from('tokens')
        .select('shop_id, status')
        .eq('id', tokenId)
        .single();

    if (token['status'] == 'cancelled') return;

    await _client.from('tokens').update({
      'status': 'cancelled',
      'cancelled_at': DateTime.now().toIso8601String(),
      'cancel_reason': 'User cancelled',
    }).eq('id', tokenId);

    // Decrement queue waiting count via RPC or direct update
    try {
      await _client.rpc('decrement_queue_count', params: {
        'p_shop_id': token['shop_id'],
      });
    } catch (_) {
      // Fallback if RPC doesn't exist
      await _client.from('queues').update({
        'total_waiting': (await _client.from('queues').select('total_waiting').eq('shop_id', token['shop_id']).single())['total_waiting'] - 1
      }).eq('shop_id', token['shop_id']);
    }
  }

  // ── Get User's Active Tokens ──────────────────────────────────
  Future<List<TokenModel>> getUserActiveTokens(String userId) async {
    final data = await _client
        .from('tokens')
        .select('*, shops(name, category, queues(current_token))')
        .eq('user_id', userId)
        .inFilter('status', ['waiting', 'called', 'serving'])
        .order('created_at', ascending: false);

    return (data as List).map((e) => TokenModel.fromJson(e)).toList();
  }

  // ── Get Token History ─────────────────────────────────────────
  Future<List<TokenModel>> getUserTokenHistory(String userId,
      {int page = 0}) async {
    final data = await _client
        .from('tokens')
        .select('*, shops(name, category)')
        .eq('user_id', userId)
        .inFilter('status', ['completed', 'cancelled', 'expired'])
        .order('created_at', ascending: false)
        .range(page * 20, (page + 1) * 20 - 1);

    return (data as List).map((e) => TokenModel.fromJson(e)).toList();
  }

  // ── Realtime: Watch token status ──────────────────────────────
  RealtimeChannel watchToken(String tokenId, Function(TokenModel) onUpdate) {
    return _client
        .channel('token:$tokenId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tokens',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: tokenId,
          ),
          callback: (payload) {
            final token = TokenModel.fromJson(payload.newRecord);
            onUpdate(token);
          },
        )
        .subscribe();
  }

  // ── Realtime: Watch queue ─────────────────────────────────────
  RealtimeChannel watchQueue(String shopId, Function(Map<String, dynamic>) onUpdate) {
    return _client
        .channel('queue:$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'queues',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  // ── Admin: Advance Queue ──────────────────────────────────────
  Future<int> advanceQueue(String shopId) async {
    final result = await _client.rpc(
      'advance_queue',
      params: {'p_shop_id': shopId},
    );
    return int.parse(result.toString());
  }

  // ── Admin: Complete Token ─────────────────────────────────────
  Future<void> completeToken(String tokenId) async {
    await _client.from('tokens').update({
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', tokenId);
  }

  // ── Admin: Mark Priority ──────────────────────────────────────
  Future<void> markTokenPriority(String tokenId, String reason) async {
    await _client.from('tokens').update({
      'is_priority': true,
      'priority_reason': reason,
    }).eq('id', tokenId);
  }

  // ── Admin: Skip Token ─────────────────────────────────────────
  Future<void> skipToken(String tokenId) async {
    await _client.from('tokens').update({
      'status': 'skipped',
    }).eq('id', tokenId);
  }

  // ── Admin: Pause/Resume Queue ─────────────────────────────────
  Future<void> pauseQueue(String shopId, {String? reason}) async {
    await _client.from('queues').update({
      'is_paused': true,
      'pause_reason': reason,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('shop_id', shopId);
  }

  Future<void> resumeQueue(String shopId) async {
    await _client.from('queues').update({
      'is_paused': false,
      'pause_reason': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('shop_id', shopId);
  }

  // ── Admin: Get all tokens for a shop ────────────────────────
  Future<List<TokenModel>> getShopTokens(String shopId,
      {String? statusFilter}) async {
    var query = _client
        .from('tokens')
        .select('*, users(full_name, phone)')
        .eq('shop_id', shopId);

    if (statusFilter != null) {
      query = query.eq('status', statusFilter);
    } else {
      query = query.inFilter('status', ['waiting', 'called', 'serving']);
    }

    final data = await query.order('token_number', ascending: true);
    return (data as List).map((e) => TokenModel.fromJson(e)).toList();
  }
}
