import 'dart:math';
import 'supabase_service.dart';
import '../models/shop_model.dart';

// ============================================================
// shop_service.dart
// ============================================================
class ShopService {
  final _client = SupabaseService.client;

  Future<List<ShopModel>> getAllShops({
    String? category,
    String? city,
    double? userLat,
    double? userLng,
    double radiusKm = 10,
  }) async {
    var query = _client
        .from('shops')
        .select('*, queues(current_token, total_waiting, is_paused)')
        .eq('is_active', true);

    if (category != null) query = query.eq('category', category);
    if (city != null) query = query.eq('city', city);

    final data = await query.order('name');
    final rawShops = data as List;

    // If user location provided, filter by radius and add distance
    if (userLat != null && userLng != null) {
      final filtered = <ShopModel>[];
      for (final raw in rawShops) {
        final shop = raw as Map<String, dynamic>;
        final lat = shop['latitude'] as double?;
        final lng = shop['longitude'] as double?;
        if (lat != null && lng != null) {
          final dist = _calculateDistance(userLat, userLng, lat, lng);
          if (dist <= radiusKm) {
            final model = ShopModel.fromJson({...shop, 'distance_km': dist});
            filtered.add(model);
          }
        } else {
          filtered.add(ShopModel.fromJson(shop));
        }
      }
      filtered.sort((a, b) =>
          (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));
      return filtered;
    }

    return rawShops.map((e) => ShopModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> getShopById(String shopId) async {
    return _client
        .from('shops')
        .select('*, queues(*)')
        .eq('id', shopId)
        .single();
  }

  Future<Map<String, dynamic>> createShop({
    required String ownerId,
    required String name,
    required String category,
    required String address,
    double? latitude,
    double? longitude,
  }) async {
    // Create shop
    final shop = await _client
        .from('shops')
        .insert({
          'owner_id': ownerId,
          'name': name,
          'category': category,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
        })
        .select()
        .single();

    // Create queue entry for the shop
    await _client.from('queues').insert({
      'shop_id': shop['id'],
    });

    return shop;
  }

  Future<void> updateShopStatus(String shopId, {required bool isOpen}) async {
    await _client.from('shops').update({
      'is_open': isOpen,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', shopId);

    if (isOpen) {
      await _client.from('queues').update({
        'opened_at': DateTime.now().toIso8601String(),
        'current_token': 0,
        'last_token_number': 0,
        'total_waiting': 0,
      }).eq('shop_id', shopId);
    }
  }

  Future<void> updateAvgServiceTime(String shopId, int minutes) async {
    await _client.from('shops').update({
      'avg_service_time_minutes': minutes,
    }).eq('id', shopId);

    await _client.from('queues').update({
      'avg_service_time': minutes.toDouble(),
    }).eq('shop_id', shopId);
  }

  // Suggest shops with shorter queues
  Future<List<Map<String, dynamic>>> getSuggestedAlternatives({
    required String category,
    required int currentWait,
    double? userLat,
    double? userLng,
  }) async {
    final data = await _client
        .from('shops')
        .select('*, queues(total_waiting, avg_service_time)')
        .eq('category', category)
        .eq('is_open', true)
        .eq('is_active', true);

    final shops = data as List<Map<String, dynamic>>;
    final alternatives = shops.where((s) {
      final queue = s['queues'] as Map?;
      if (queue == null) return false;
      final wait = ((queue['total_waiting'] ?? 0) as num) *
          ((queue['avg_service_time'] ?? 5) as num);
      return wait < currentWait;
    }).toList();

    return alternatives;
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371; // Earth radius km
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * pi / 180;
}

