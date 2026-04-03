import 'dart:math';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// AI-based wait time prediction engine.
/// Uses exponential moving average over historical queue data,
/// grouped by hour-of-day and day-of-week for accuracy.
class AiPredictionService {
  final _client = SupabaseService.client;

  // ── Primary prediction ───────────────────────────────────────

  /// Returns predicted wait time (minutes) for the given queue state.
  Future<int> predictWaitTime({
    required String shopId,
    required int queueLength,
    required double currentAvgServiceTime,
  }) async {
    if (queueLength <= 0) return 0;

    final now = DateTime.now();
    final hourOfDay = now.hour;
    final dayOfWeek = now.weekday; // 1=Mon … 7=Sun

    try {
      // Fetch recent historical predictions with actual wait recorded
      final history = await _client
          .from('ai_predictions')
          .select('actual_wait, queue_length, predicted_wait')
          .eq('shop_id', shopId)
          .eq('hour_of_day', hourOfDay)
          .eq('day_of_week', dayOfWeek)
          .not('actual_wait', 'is', null)
          .order('created_at', ascending: false)
          .limit(30);

      int predicted;
      if ((history as List).isEmpty) {
        predicted = _simpleCalc(queueLength, currentAvgServiceTime);
      } else {
        predicted = _emaPredict(history, queueLength, currentAvgServiceTime);
      }

      // Store this prediction for future learning
      await _storePrediction(
        shopId: shopId,
        queueLength: queueLength,
        hourOfDay: hourOfDay,
        dayOfWeek: dayOfWeek,
        avgServiceTime: currentAvgServiceTime,
        predicted: predicted,
      );

      return predicted;
    } catch (e) {
      debugPrint('AI prediction error: $e');
      return _simpleCalc(queueLength, currentAvgServiceTime);
    }
  }

  // ── Peak hours analysis ──────────────────────────────────────

  Future<Map<String, dynamic>> getPeakHoursAnalysis(String shopId,
      {int lastNDays = 30}) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: lastNDays));
      final data = await _client
          .from('analytics')
          .select('hourly_data, peak_hour, total_customers, date')
          .eq('shop_id', shopId)
          .gte('date', cutoff.toIso8601String().split('T')[0])
          .order('date', ascending: false);

      final analytics = data as List;
      if (analytics.isEmpty) return _emptyPeakData();

      // Aggregate hourly data across all days
      final hourlyTotals = <int, int>{};
      int totalDays = 0;

      for (final day in analytics) {
        final hourly = (day['hourly_data'] as Map?)?.cast<String, dynamic>() ?? {};
        if (hourly.isNotEmpty) totalDays++;
        for (final entry in hourly.entries) {
          final hour = int.tryParse(entry.key);
          if (hour == null) continue;
          final count = (entry.value as num?)?.toInt() ?? 0;
          hourlyTotals[hour] = (hourlyTotals[hour] ?? 0) + count;
        }
      }

      // Average per day
      final hourlyAvg = hourlyTotals.map(
        (h, total) => MapEntry(h, totalDays > 0 ? (total / totalDays).round() : total),
      );

      int peakHour = 12;
      int peakCount = 0;
      for (final e in hourlyAvg.entries) {
        if (e.value > peakCount) {
          peakCount = e.value;
          peakHour = e.key;
        }
      }

      return {
        'hourly_averages': hourlyAvg,
        'peak_hour': peakHour,
        'peak_count': peakCount,
        'total_days_analyzed': totalDays,
      };
    } catch (e) {
      debugPrint('Peak hour analysis error: $e');
      return _emptyPeakData();
    }
  }

  // ── Accuracy report ──────────────────────────────────────────

  Future<Map<String, dynamic>> getPredictionAccuracy(String shopId) async {
    try {
      final data = await _client
          .from('ai_predictions')
          .select('predicted_wait, actual_wait')
          .eq('shop_id', shopId)
          .not('actual_wait', 'is', null)
          .order('created_at', ascending: false)
          .limit(100);

      final rows = data as List;
      if (rows.isEmpty) return {'accuracy': 0.0, 'samples': 0};

      double totalError = 0;
      int count = 0;
      for (final row in rows) {
        final predicted = (row['predicted_wait'] as num?)?.toDouble() ?? 0;
        final actual = (row['actual_wait'] as num?)?.toDouble() ?? 0;
        if (actual > 0) {
          totalError += (predicted - actual).abs() / actual;
          count++;
        }
      }

      final mape = count > 0 ? (totalError / count) * 100 : 0;
      final accuracy = (100 - mape).clamp(0, 100);

      return {
        'accuracy': accuracy.toStringAsFixed(1),
        'samples': count,
        'mean_absolute_percentage_error': mape.toStringAsFixed(1),
      };
    } catch (e) {
      return {'accuracy': 'N/A', 'samples': 0};
    }
  }

  // ── Record actual wait (called when token completes) ─────────

  Future<void> recordActualWait({
    required String shopId,
    required int actualWaitMinutes,
  }) async {
    try {
      // Find most recent un-completed prediction for this shop
      final rows = await _client
          .from('ai_predictions')
          .select('id')
          .eq('shop_id', shopId)
          .isFilter('actual_wait', null)
          .order('created_at', ascending: false)
          .limit(1);

      if ((rows as List).isNotEmpty) {
        await _client
            .from('ai_predictions')
            .update({'actual_wait': actualWaitMinutes}).eq(
                'id', rows[0]['id'] as String);
      }
    } catch (e) {
      debugPrint('Record actual wait error: $e');
    }
  }

  // ── Crowd surge detection ────────────────────────────────────

  /// Returns true if current queue is unusually busy vs historical average
  Future<bool> isBusierThanUsual({
    required String shopId,
    required int currentQueueLength,
  }) async {
    try {
      final now = DateTime.now();
      final history = await _client
          .from('ai_predictions')
          .select('queue_length')
          .eq('shop_id', shopId)
          .eq('hour_of_day', now.hour)
          .order('created_at', ascending: false)
          .limit(20);

      final rows = history as List;
      if (rows.length < 5) return false;

      final avgQueue = rows.fold<double>(
            0,
            (sum, r) => sum + ((r['queue_length'] as num?)?.toDouble() ?? 0),
          ) /
          rows.length;

      return currentQueueLength > avgQueue * 1.5;
    } catch (_) {
      return false;
    }
  }

  // ── Private helpers ──────────────────────────────────────────

  int _simpleCalc(int queueLength, double avgServiceTime) =>
      (queueLength * avgServiceTime).round().clamp(0, 999);

  int _emaPredict(
    List history,
    int currentQueueLength,
    double currentAvgServiceTime,
  ) {
    // Extract per-customer wait times from historical records
    final perCustomerWaits = <double>[];
    for (final row in history) {
      final actual = (row['actual_wait'] as num?)?.toDouble();
      final ql = (row['queue_length'] as num?)?.toDouble();
      if (actual != null && ql != null && ql > 0) {
        perCustomerWaits.add(actual / ql);
      }
    }

    if (perCustomerWaits.isEmpty) {
      return _simpleCalc(currentQueueLength, currentAvgServiceTime);
    }

    // Exponential Moving Average (more weight to recent data)
    const alpha = 0.3;
    double ema = perCustomerWaits.first;
    for (int i = 1; i < perCustomerWaits.length; i++) {
      ema = alpha * perCustomerWaits[i] + (1 - alpha) * ema;
    }

    // Blend EMA with current avg service time (50/50)
    final blended = (ema + currentAvgServiceTime) / 2;
    return (currentQueueLength * blended).round().clamp(0, 999);
  }

  Future<void> _storePrediction({
    required String shopId,
    required int queueLength,
    required int hourOfDay,
    required int dayOfWeek,
    required double avgServiceTime,
    required int predicted,
  }) async {
    try {
      await _client.from('ai_predictions').insert({
        'shop_id': shopId,
        'queue_length': queueLength,
        'hour_of_day': hourOfDay,
        'day_of_week': dayOfWeek,
        'avg_service_time': avgServiceTime,
        'predicted_wait': predicted,
      });
    } catch (e) {
      debugPrint('Store prediction error: $e');
    }
  }

  Map<String, dynamic> _emptyPeakData() => {
        'hourly_averages': <int, int>{},
        'peak_hour': null,
        'peak_count': 0,
        'total_days_analyzed': 0,
      };
}