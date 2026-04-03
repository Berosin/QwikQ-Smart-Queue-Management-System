// ============================================================
// queue_model.dart
// ============================================================
class QueueModel {
  final String id;
  final String shopId;
  final int currentToken;
  final int lastTokenNumber;
  final int totalWaiting;
  final double avgServiceTime;
  final bool isPaused;
  final String? pauseReason;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final DateTime updatedAt;

  const QueueModel({
    required this.id,
    required this.shopId,
    this.currentToken = 0,
    this.lastTokenNumber = 0,
    this.totalWaiting = 0,
    this.avgServiceTime = 5.0,
    this.isPaused = false,
    this.pauseReason,
    this.openedAt,
    this.closedAt,
    required this.updatedAt,
  });

  factory QueueModel.fromJson(Map<String, dynamic> json) => QueueModel(
        id: json['id'] as String,
        shopId: json['shop_id'] as String,
        currentToken: json['current_token'] as int? ?? 0,
        lastTokenNumber: json['last_token_number'] as int? ?? 0,
        totalWaiting: json['total_waiting'] as int? ?? 0,
        avgServiceTime: (json['avg_service_time'] as num?)?.toDouble() ?? 5.0,
        isPaused: json['is_paused'] as bool? ?? false,
        pauseReason: json['pause_reason'] as String?,
        openedAt: json['opened_at'] != null
            ? DateTime.parse(json['opened_at'] as String)
            : null,
        closedAt: json['closed_at'] != null
            ? DateTime.parse(json['closed_at'] as String)
            : null,
        updatedAt: DateTime.parse(
            json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'shop_id': shopId,
        'current_token': currentToken,
        'last_token_number': lastTokenNumber,
        'total_waiting': totalWaiting,
        'avg_service_time': avgServiceTime,
        'is_paused': isPaused,
        'pause_reason': pauseReason,
        'opened_at': openedAt?.toIso8601String(),
        'closed_at': closedAt?.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  // ── Computed ─────────────────────────────────────────────────

  /// Estimated wait minutes for a given token number
  int estimatedWaitFor(int tokenNumber) {
    final position = (tokenNumber - currentToken).clamp(0, 9999);
    return (position * avgServiceTime).round();
  }

  /// Tokens served so far today
  int get tokensServed => currentToken;

  /// Percentage of daily capacity used (if maxTokens is known)
  double capacityRatio(int maxTokens) =>
      maxTokens == 0 ? 0 : (lastTokenNumber / maxTokens).clamp(0.0, 1.0);

  QueueModel copyWith({
    int? currentToken,
    int? lastTokenNumber,
    int? totalWaiting,
    double? avgServiceTime,
    bool? isPaused,
    String? pauseReason,
  }) =>
      QueueModel(
        id: id,
        shopId: shopId,
        currentToken: currentToken ?? this.currentToken,
        lastTokenNumber: lastTokenNumber ?? this.lastTokenNumber,
        totalWaiting: totalWaiting ?? this.totalWaiting,
        avgServiceTime: avgServiceTime ?? this.avgServiceTime,
        isPaused: isPaused ?? this.isPaused,
        pauseReason: pauseReason ?? this.pauseReason,
        openedAt: openedAt,
        closedAt: closedAt,
        updatedAt: DateTime.now(),
      );
}
