// ============================================================
// user_model.dart
// ============================================================
class UserModel {
  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final String role;
  final int points;
  final List<String> badges;
  final int totalTokensBooked;
  final int onTimeArrivals;
  final bool isBlocked;
  final String? fcmToken;

  const UserModel({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.avatarUrl,
    this.role = 'user',
    this.points = 0,
    this.badges = const [],
    this.totalTokensBooked = 0,
    this.onTimeArrivals = 0,
    this.isBlocked = false,
    this.fcmToken,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        fullName: json['full_name'] ?? '',
        phone: json['phone'],
        email: json['email'],
        avatarUrl: json['avatar_url'],
        role: json['role'] ?? 'user',
        points: json['points'] ?? 0,
        badges: List<String>.from(json['badges'] ?? []),
        totalTokensBooked: json['total_tokens_booked'] ?? 0,
        onTimeArrivals: json['on_time_arrivals'] ?? 0,
        isBlocked: json['is_blocked'] ?? false,
        fcmToken: json['fcm_token'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'avatar_url': avatarUrl,
        'role': role,
        'points': points,
        'badges': badges,
        'total_tokens_booked': totalTokensBooked,
        'on_time_arrivals': onTimeArrivals,
        'is_blocked': isBlocked,
        'fcm_token': fcmToken,
      };

  bool get isAdmin => role == 'admin' || role == 'super_admin';
}