
// ============================================================
// analytics_model.dart
// ============================================================
class AnalyticsModel {
  final String id;
  final String shopId;
  final DateTime date;
  final int totalCustomers;
  final int totalCompleted;
  final int totalCancelled;
  final int totalNoShows;
  final double avgWaitTime;
  final double avgServiceTime;
  final int? peakHour;
  final int peakCount;
  final Map<String, int> hourlyData; // "9" → 23, "10" → 45 ...

  const AnalyticsModel({
    required this.id,
    required this.shopId,
    required this.date,
    this.totalCustomers = 0,
    this.totalCompleted = 0,
    this.totalCancelled = 0,
    this.totalNoShows = 0,
    this.avgWaitTime = 0,
    this.avgServiceTime = 0,
    this.peakHour,
    this.peakCount = 0,
    this.hourlyData = const {},
  });

  factory AnalyticsModel.fromJson(Map<String, dynamic> json) {
    final rawHourly = json['hourly_data'] as Map<String, dynamic>? ?? {};
    final hourlyData = rawHourly.map(
      (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
    );
    return AnalyticsModel(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      date: DateTime.parse(json['date'] as String),
      totalCustomers: json['total_customers'] as int? ?? 0,
      totalCompleted: json['total_completed'] as int? ?? 0,
      totalCancelled: json['total_cancelled'] as int? ?? 0,
      totalNoShows: json['total_no_shows'] as int? ?? 0,
      avgWaitTime: (json['avg_wait_time'] as num?)?.toDouble() ?? 0,
      avgServiceTime: (json['avg_service_time'] as num?)?.toDouble() ?? 0,
      peakHour: json['peak_hour'] as int?,
      peakCount: json['peak_count'] as int? ?? 0,
      hourlyData: hourlyData,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'shop_id': shopId,
        'date': date.toIso8601String().split('T')[0],
        'total_customers': totalCustomers,
        'total_completed': totalCompleted,
        'total_cancelled': totalCancelled,
        'total_no_shows': totalNoShows,
        'avg_wait_time': avgWaitTime,
        'avg_service_time': avgServiceTime,
        'peak_hour': peakHour,
        'peak_count': peakCount,
        'hourly_data': hourlyData,
      };

  // ── Computed ─────────────────────────────────────────────────

  double get completionRate =>
      totalCustomers == 0 ? 0 : totalCompleted / totalCustomers;

  double get cancellationRate =>
      totalCustomers == 0 ? 0 : totalCancelled / totalCustomers;

  double get noShowRate =>
      totalCustomers == 0 ? 0 : totalNoShows / totalCustomers;

  /// Top 3 busiest hours sorted descending
  List<MapEntry<String, int>> get topHours {
    final entries = hourlyData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(3).toList();
  }

  String get peakHourLabel {
    if (peakHour == null) return 'N/A';
    final h = peakHour!;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final display = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$display $suffix';
  }
}

// ── Weekly analytics summary ──────────────────────────────────
class WeeklyAnalytics {
  final List<AnalyticsModel> days;

  const WeeklyAnalytics(this.days);

  int get totalCustomers => days.fold(0, (s, d) => s + d.totalCustomers);
  int get totalCompleted => days.fold(0, (s, d) => s + d.totalCompleted);
  double get avgWaitTime {
    final filled = days.where((d) => d.avgWaitTime > 0).toList();
    if (filled.isEmpty) return 0;
    return filled.fold(0.0, (s, d) => s + d.avgWaitTime) / filled.length;
  }

  double get overallCompletionRate =>
      totalCustomers == 0 ? 0 : totalCompleted / totalCustomers;

  // For fl_chart line chart — (dayIndex, totalCustomers) spots
  List<Map<String, double>> get dailySpots => days.asMap().entries.map((e) {
        return {'x': e.key.toDouble(), 'y': e.value.totalCustomers.toDouble()};
      }).toList();
}