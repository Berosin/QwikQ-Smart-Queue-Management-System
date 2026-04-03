
// ============================================================
// token_model.dart
// ============================================================
enum TokenStatus {
  waiting,
  called,
  serving,
  completed,
  cancelled,
  expired,
  skipped
}

class TokenModel {
  final String id;
  final int tokenNumber;
  final String shopId;
  final String userId;
  final int groupSize;
  final TokenStatus status;
  final bool isPriority;
  final String? priorityReason;
  final String bookingType;
  final DateTime? slotStartTime;
  final DateTime? slotEndTime;
  final int? estimatedWaitMinutes;
  final int? actualWaitMinutes;
  final int? aiPredictedWait;
  final String? qrCode;
  final DateTime? arrivedAt;
  final DateTime? servedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? expiryTime;
  final DateTime createdAt;

  // Joined fields
  final String? shopName;
  final String? shopCategory;
  final int? currentQueueToken;

  const TokenModel({
    required this.id,
    required this.tokenNumber,
    required this.shopId,
    required this.userId,
    this.groupSize = 1,
    required this.status,
    this.isPriority = false,
    this.priorityReason,
    this.bookingType = 'token',
    this.slotStartTime,
    this.slotEndTime,
    this.estimatedWaitMinutes,
    this.actualWaitMinutes,
    this.aiPredictedWait,
    this.qrCode,
    this.arrivedAt,
    this.servedAt,
    this.completedAt,
    this.cancelledAt,
    this.expiryTime,
    required this.createdAt,
    this.shopName,
    this.shopCategory,
    this.currentQueueToken,
  });

  factory TokenModel.fromJson(Map<String, dynamic> json) => TokenModel(
        id: json['id'],
        tokenNumber: json['token_number'],
        shopId: json['shop_id'],
        userId: json['user_id'],
        groupSize: json['group_size'] ?? 1,
        status: TokenStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => TokenStatus.waiting,
        ),
        isPriority: json['is_priority'] ?? false,
        priorityReason: json['priority_reason'],
        bookingType: json['booking_type'] ?? 'token',
        slotStartTime: json['slot_start_time'] != null
            ? DateTime.parse(json['slot_start_time'])
            : null,
        slotEndTime: json['slot_end_time'] != null
            ? DateTime.parse(json['slot_end_time'])
            : null,
        estimatedWaitMinutes: json['estimated_wait_minutes'],
        actualWaitMinutes: json['actual_wait_minutes'],
        aiPredictedWait: json['ai_predicted_wait'],
        qrCode: json['qr_code'],
        arrivedAt: json['arrived_at'] != null
            ? DateTime.parse(json['arrived_at'])
            : null,
        servedAt: json['served_at'] != null
            ? DateTime.parse(json['served_at'])
            : null,
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'])
            : null,
        cancelledAt: json['cancelled_at'] != null
            ? DateTime.parse(json['cancelled_at'])
            : null,
        expiryTime: json['expiry_time'] != null
            ? DateTime.parse(json['expiry_time'])
            : null,
        createdAt: DateTime.parse(json['created_at']),
        shopName: json['shops']?['name'],
        shopCategory: json['shops']?['category'],
        currentQueueToken: json['shops']?['queues']?['current_token'],
      );

  int get positionInQueue =>
      currentQueueToken != null ? tokenNumber - currentQueueToken! : 0;

  bool get isActive =>
      status == TokenStatus.waiting ||
      status == TokenStatus.called ||
      status == TokenStatus.serving;
}

