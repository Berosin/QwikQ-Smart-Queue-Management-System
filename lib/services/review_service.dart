import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class ReviewService {
  final _client = SupabaseService.client;

  Future<void> submitReview({
    required String shopId,
    required String userId,
    required String tokenId,
    required int rating,
    String? comment,
  }) async {
    try {
      // 1. Insert the review
      await _client.from('reviews').insert({
        'shop_id': shopId,
        'user_id': userId,
        'token_id': tokenId,
        'rating': rating,
        'comment': comment ?? '',
      });

      // 2. Award points via RPC
      await _client.rpc('award_points', params: {
        'p_user_id': userId,
        'p_points': 10,
      });

      // 3. Update shop stats
      final shopData = await _client
          .from('shops')
          .select('rating, total_ratings')
          .eq('id', shopId)
          .single();

      double currentRating = (shopData['rating'] as num?)?.toDouble() ?? 0.0;
      int totalRatings = (shopData['total_ratings'] as int?) ?? 0;
      double newRating = ((currentRating * totalRatings) + rating) / (totalRatings + 1);
      
      await _client.from('shops').update({
        'rating': newRating,
        'total_ratings': totalRatings + 1,
      }).eq('id', shopId);

    } catch (e) {
      print('Review Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getReviewForToken(String tokenId) async {
    final data = await _client
        .from('reviews')
        .select()
        .eq('token_id', tokenId)
        .maybeSingle();
    return data;
  }

  Future<List<Map<String, dynamic>>> getUserReviews(String userId) async {
    final data = await _client
        .from('reviews')
        .select('*, shops(name, category)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }
}
