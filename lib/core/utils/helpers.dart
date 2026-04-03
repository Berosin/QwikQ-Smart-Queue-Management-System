import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';

class Helpers {
  Helpers._();

  // ── Date & Time ──────────────────────────────────────────────

  /// "2 min ago", "1 hr ago", "Yesterday"
  static String timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('dd MMM yyyy').format(dateTime);
  }

  /// "12:30 PM"
  static String formatTime(DateTime dt) => DateFormat('hh:mm a').format(dt);

  /// "Mon, 2 Apr 2026"
  static String formatDate(DateTime dt) =>
      DateFormat('EEE, d MMM yyyy').format(dt);

  /// "2:15 PM - 2:30 PM"
  static String formatSlotRange(DateTime start, DateTime end) =>
      '${formatTime(start)} – ${formatTime(end)}';

  /// Greeting based on hour
  static String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  // ── Queue & Wait Time ────────────────────────────────────────

  /// "~5 min", "~1 hr 20 min"
  static String formatWaitTime(int minutes) {
    if (minutes <= 0) return 'Now!';
    if (minutes < 60) return '~$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '~${h}h' : '~${h}h ${m}m';
  }

  /// Queue position ordinal: 1 → "1st", 2 → "2nd"
  static String ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1: return '${n}st';
      case 2: return '${n}nd';
      case 3: return '${n}rd';
      default: return '${n}th';
    }
  }

  // ── Colors ───────────────────────────────────────────────────

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':   return AppColors.statusWaiting;
      case 'called':    return AppColors.electricBlue;
      case 'serving':   return AppColors.neonGreen;
      case 'completed': return AppColors.statusCompleted;
      case 'cancelled': return AppColors.statusCancelled;
      case 'expired':   return AppColors.statusExpired;
      case 'skipped':   return AppColors.textMuted;
      default:          return AppColors.textMuted;
    }
  }

  static Color crowdColor(int count) {
    if (count <= 5) return AppColors.crowdLow;
    if (count <= 15) return AppColors.crowdMedium;
    return AppColors.crowdHigh;
  }

  /// Category Icon Data
  static IconData categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'canteen':    return Icons.restaurant;
      case 'hospital':   return Icons.local_hospital;
      case 'bank':       return Icons.account_balance;
      case 'clinic':     return Icons.medical_services;
      case 'salon':      return Icons.content_cut;
      case 'pharmacy':   return Icons.local_pharmacy;
      case 'government': return Icons.gavel;
      case 'other':      return Icons.storefront;
      default:          return Icons.storefront;
    }
  }

  /// Category label
  static String categoryLabel(String category) {
    if (category.isEmpty) return 'Other';
    return category[0].toUpperCase() + category.substring(1).toLowerCase();
  }

  // ── UI Helpers ───────────────────────────────────────────────

  static void showSnack(
    BuildContext context,
    String message, {
    bool isError = false,
    String? action,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red : AppColors.neonGreen,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        action: action != null
            ? SnackBarAction(label: action, onPressed: onAction ?? () {})
            : null,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: destructive ? Colors.red : AppColors.electricBlue,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  // ── Number Formatting ────────────────────────────────────────

  static String compactNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  // ── Gamification ─────────────────────────────────────────────

  static String pointsLabel(int points) {
    if (points < 100) return 'Newcomer';
    if (points < 500) return 'Regular';
    if (points < 1000) return 'Pro';
    if (points < 5000) return 'Expert';
    return 'Legend';
  }

  static Color pointsColor(int points) {
    if (points < 100) return AppColors.textMuted;
    if (points < 500) return AppColors.electricBlue;
    if (points < 1000) return AppColors.neonGreen;
    if (points < 5000) return Colors.amber;
    return Colors.deepOrange;
  }

  // ── String Utils ─────────────────────────────────────────────

  static String initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static String maskPhone(String phone) {
    if (phone.length < 6) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 3)}';
  }

  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name[0]}***@$domain';
    return '${name[0]}${name[1]}***@$domain';
  }
}