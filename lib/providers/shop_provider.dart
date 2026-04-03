import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/shop_model.dart';
import '../services/shop_service.dart';
import '../services/supabase_service.dart';


// ── Service provider ──────────────────────────────────────────
final shopServiceProvider = Provider<ShopService>((ref) => ShopService());

// ── User's current location ───────────────────────────────────
final userLocationProvider = FutureProvider.autoDispose<Position?>((ref) async {
  try {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  } catch (_) {
    return null;
  }
});

// Add to shop_provider.dart
final shopDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, shopId) async {
    return ref.read(shopServiceProvider).getShopById(shopId);
  },
);

// ── Nearby shops filter state ─────────────────────────────────
class ShopFilter {
  final String? category;
  final String? city;
  final String? searchQuery;
  final double radiusKm;
  final bool openOnly;

  const ShopFilter({
    this.category,
    this.city,
    this.searchQuery,
    this.radiusKm = 10,
    this.openOnly = false,
  });

  ShopFilter copyWith({
    String? category,
    String? city,
    String? searchQuery,
    double? radiusKm,
    bool? openOnly,
    bool clearCategory = false,
  }) =>
      ShopFilter(
        category: clearCategory ? null : category ?? this.category,
        city: city ?? this.city,
        searchQuery: searchQuery ?? this.searchQuery,
        radiusKm: radiusKm ?? this.radiusKm,
        openOnly: openOnly ?? this.openOnly,
      );
}

final shopFilterProvider = StateProvider<ShopFilter>((ref) => const ShopFilter());

// ── All shops (with filter + location) ───────────────────────
final nearbyShopsProvider = FutureProvider.autoDispose<List<ShopModel>>((ref) async {
  final filter = ref.watch(shopFilterProvider);
  final locationAsync = ref.watch(userLocationProvider);
  final position = locationAsync.valueOrNull;

  final service = ref.read(shopServiceProvider);
  var shops = await service.getAllShops(
    category: filter.category,
    city: filter.city,
    userLat: position?.latitude,
    userLng: position?.longitude,
    radiusKm: filter.radiusKm,
  );

  // Local filtering
  if (filter.openOnly) {
    shops = shops.where((s) => s.isOpen).toList();
  }
  if (filter.searchQuery?.isNotEmpty == true) {
    final q = filter.searchQuery!.toLowerCase();
    shops = shops.where((s) =>
        s.name.toLowerCase().contains(q) ||
        (s.address?.toLowerCase().contains(q) ?? false) ||
        s.category.toLowerCase().contains(q)).toList();
  }

  return shops;
});

// ── Single shop by ID ─────────────────────────────────────────
final shopByIdProvider = FutureProvider.autoDispose.family<ShopModel, String>(
  (ref, shopId) async {
    final data = await ref.read(shopServiceProvider).getShopById(shopId);
    return ShopModel.fromJson(data);
  },
);

// ── Shops owned by an admin ───────────────────────────────────
final adminOwnedShopsProvider =
    FutureProvider.autoDispose.family<List<ShopModel>, String>(
  (ref, ownerId) async {
    final data = await SupabaseService.client
        .from('shops')
        .select('*, queues(current_token, total_waiting, is_paused, avg_service_time)')
        .eq('owner_id', ownerId)
        .eq('is_active', true)
        .order('name');
    return (data as List).map((e) => ShopModel.fromJson(e)).toList();
  },
);

// ── Alternative shops (shorter queue) ────────────────────────
final alternativeShopsProvider =
    FutureProvider.autoDispose.family<List<ShopModel>, Map<String, dynamic>>(
  (ref, params) async {
    final service = ref.read(shopServiceProvider);
    final alts = await service.getSuggestedAlternatives(
      category: params['category'] as String,
      currentWait: params['currentWait'] as int,
      userLat: params['lat'] as double?,
      userLng: params['lng'] as double?,
    );
    return alts.map((e) => ShopModel.fromJson(e)).toList();
  },
);

// ── Shop creation/management notifier ────────────────────────
class ShopManagementNotifier extends StateNotifier<AsyncValue<ShopModel?>> {
  final ShopService _service;

  ShopManagementNotifier(this._service) : super(const AsyncValue.data(null));

  Future<ShopModel?> createShop({
    required String ownerId,
    required String name,
    required String category,
    required String address,
    String? city,
    double? latitude,
    double? longitude,
    String? phone,
    int avgServiceTime = 5,
    bool allowSlotBooking = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      final data = await _service.createShop(
        ownerId: ownerId,
        name: name,
        category: category,
        address: address,
        latitude: latitude,
        longitude: longitude,
      );
      final shop = ShopModel.fromJson(data);
      state = AsyncValue.data(shop);
      return shop;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> toggleShopOpen(String shopId, {required bool isOpen}) async {
    try {
      await _service.updateShopStatus(shopId, isOpen: isOpen);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> updateServiceTime(String shopId, int minutes) async {
    try {
      await _service.updateAvgServiceTime(shopId, minutes);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final shopManagementProvider =
    StateNotifierProvider<ShopManagementNotifier, AsyncValue<ShopModel?>>(
  (ref) => ShopManagementNotifier(ref.read(shopServiceProvider)),
);