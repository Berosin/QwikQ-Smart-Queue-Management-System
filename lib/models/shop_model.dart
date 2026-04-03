import 'package:flutter/material.dart';
import '../core/utils/helpers.dart';

class ShopModel {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String category;
  final String? address;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? logoUrl;
  final String? qrCode;
  final int avgServiceTimeMinutes;
  final bool isActive;
  final bool isOpen;
  final String? openingTime;
  final String? closingTime;
  final int maxTokensPerDay;
  final int maxTokensPerUser;
  final bool allowSlotBooking;
  final int slotDurationMinutes;
  final String? branchId;
  final double rating;
  final int totalRatings;
  double? distanceKm;

  // Joined queue fields (optional)
  final int? currentToken;
  final int? totalWaiting;
  final bool? isPaused;

  ShopModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    required this.category,
    this.address,
    this.city,
    this.latitude,
    this.longitude,
    this.phone,
    this.logoUrl,
    this.qrCode,
    this.avgServiceTimeMinutes = 5,
    this.isActive = true,
    this.isOpen = false,
    this.openingTime,
    this.closingTime,
    this.maxTokensPerDay = 200,
    this.maxTokensPerUser = 3,
    this.allowSlotBooking = false,
    this.slotDurationMinutes = 15,
    this.branchId,
    this.rating = 0.0,
    this.totalRatings = 0,
    this.distanceKm,
    this.currentToken,
    this.totalWaiting,
    this.isPaused,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    final queue = json['queues'] as Map<String, dynamic>?;
    return ShopModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'other',
      address: json['address'] as String?,
      city: json['city'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      phone: json['phone'] as String?,
      logoUrl: json['logo_url'] as String?,
      qrCode: json['qr_code'] as String?,
      avgServiceTimeMinutes: json['avg_service_time_minutes'] as int? ?? 5,
      isActive: json['is_active'] as bool? ?? true,
      isOpen: json['is_open'] as bool? ?? false,
      openingTime: json['opening_time'] as String?,
      closingTime: json['closing_time'] as String?,
      maxTokensPerDay: json['max_tokens_per_day'] as int? ?? 200,
      maxTokensPerUser: json['max_tokens_per_user'] as int? ?? 3,
      allowSlotBooking: json['allow_slot_booking'] as bool? ?? false,
      slotDurationMinutes: json['slot_duration_minutes'] as int? ?? 15,
      branchId: json['branch_id'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: json['total_ratings'] as int? ?? 0,
      currentToken: queue?['current_token'] as int?,
      totalWaiting: queue?['total_waiting'] as int?,
      isPaused: queue?['is_paused'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'name': name,
        'description': description,
        'category': category,
        'address': address,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        'phone': phone,
        'logo_url': logoUrl,
        'qr_code': qrCode,
        'avg_service_time_minutes': avgServiceTimeMinutes,
        'is_active': isActive,
        'is_open': isOpen,
        'max_tokens_per_day': maxTokensPerDay,
        'max_tokens_per_user': maxTokensPerUser,
        'allow_slot_booking': allowSlotBooking,
        'slot_duration_minutes': slotDurationMinutes,
        'branch_id': branchId,
        'rating': rating,
        'total_ratings': totalRatings,
      };

  // ── Computed Properties ──────────────────────────────────────

  bool get hasLocation => latitude != null && longitude != null;

  int get estimatedWaitMinutes =>
      ((totalWaiting ?? 0) * avgServiceTimeMinutes).clamp(0, 999);

  IconData get categoryIcon => Helpers.categoryIcon(category);

  String get distanceLabel {
    if (distanceKm == null) return '';
    if (distanceKm! < 1) return '${(distanceKm! * 1000).round()} m';
    return '${distanceKm!.toStringAsFixed(1)} km';
  }

  String get statusLabel {
    if (!isOpen) return 'Closed';
    if (isPaused == true) return 'Paused';
    return 'Open';
  }

  ShopModel copyWith({
    bool? isOpen,
    int? currentToken,
    int? totalWaiting,
    bool? isPaused,
    double? distanceKm,
  }) => ShopModel(
        id: id,
        ownerId: ownerId,
        name: name,
        description: description,
        category: category,
        address: address,
        city: city,
        latitude: latitude,
        longitude: longitude,
        phone: phone,
        logoUrl: logoUrl,
        qrCode: qrCode,
        avgServiceTimeMinutes: avgServiceTimeMinutes,
        isActive: isActive,
        isOpen: isOpen ?? this.isOpen,
        maxTokensPerDay: maxTokensPerDay,
        maxTokensPerUser: maxTokensPerUser,
        allowSlotBooking: allowSlotBooking,
        slotDurationMinutes: slotDurationMinutes,
        branchId: branchId,
        rating: rating,
        totalRatings: totalRatings,
        distanceKm: distanceKm ?? this.distanceKm,
        currentToken: currentToken ?? this.currentToken,
        totalWaiting: totalWaiting ?? this.totalWaiting,
        isPaused: isPaused ?? this.isPaused,
      );
}